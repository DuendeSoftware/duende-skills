---
name: identityserver-key-management
description: Managing cryptographic signing keys in Duende IdentityServer, including automatic key management, KeyManagementOptions, data protection at rest, static key configuration, migration from static to automatic, and multi-instance deployment considerations, HSM/cloud KMS signing, key backup, and key-compromise response.
invocable: false
---

# Key Management and Signing

## When to Use This Skill

- Configuring automatic key management for signing token keys
- Setting up static/manual signing keys from certificates or key vaults
- Configuring key rotation intervals and key lifecycle
- Migrating from static keys to automatic key management
- Deploying IdentityServer in load-balanced or multi-instance environments
- Protecting keys at rest using data protection
- Configuring per-algorithm or per-resource signing
- Troubleshooting key-related errors (CryptographicException, unprotecting key failures)
- Integrating an HSM or cloud KMS (e.g. Azure Key Vault) for signing
- Backing up signing keys and responding to a suspected key compromise

Docs: https://docs.duendesoftware.com/identityserver/fundamentals/key-management/

## Core Concepts

IdentityServer issues cryptographically signed tokens: identity tokens, JWT access tokens, and logout tokens. These signatures require key material that can be managed automatically or manually (statically).

### Supported Signing Algorithms

IdentityServer supports the `RS`, `PS`, and `ES` families:

| Family | Algorithms                | Key Type |
| ------ | ------------------------- | -------- |
| RS     | `RS256`, `RS384`, `RS512` | RSA      |
| PS     | `PS256`, `PS384`, `PS512` | RSA      |
| ES     | `ES256`, `ES384`, `ES512` | ECDSA    |

### Core Rotation Rule

Regardless of approach, safe rotation obeys one rule: **publish a new public key in discovery (JWKS) BEFORE using it to sign tokens, and keep a RETIRED public key published until every token signed with it has expired.** Automatic Key Management enforces this overlap for you (Announced → Signing → Retired phases). With static/manual keys you must perform the overlap yourself via phased rotation (see [Manual Key Rotation](#manual-key-rotation-phased-approach)).

## Automatic Key Management (Recommended)

Automatic Key Management handles key creation, rotation, announcement, and retirement. It is enabled by default and is part of the Business and Enterprise editions (per the current licensing page: an add-on for the Standard edition, included in Advanced/Enterprise; the entry-level edition is now called Lite). In v8 a missing entitlement throws at startup.

### Key Lifecycle

Keys move through four phases:

```
Announced --> Signing --> Retired --> Deleted
   |             |            |          |
   |<--Propagation-->|        |          |
   |             |<--Rotation-->|        |
   |             |            |<--Retention-->|
```

| Phase         | Duration (default)                           | Purpose                                       |
| ------------- | -------------------------------------------- | --------------------------------------------- |
| **Announced** | 14 days (`PropagationTime`)                  | Published in discovery, not yet signing       |
| **Signing**   | 76 days (RotationInterval - PropagationTime) | Active signing credential                     |
| **Retired**   | 14 days (`RetentionDuration`)                | In discovery for token validation only        |
| **Deleted**   | After retention                              | Removed from discovery and optionally deleted |

**Default schedule:** Keys rotate every 90 days, announced 14 days early, retained 14 days after rotation.

### Configuration

```csharp
// Program.cs
var idsvrBuilder = builder.Services.AddIdentityServer(options =>
{
    // Key rotates every 30 days
    options.KeyManagement.RotationInterval = TimeSpan.FromDays(30);

    // Announce new key 2 days in advance in discovery
    options.KeyManagement.PropagationTime = TimeSpan.FromDays(2);

    // Keep old key for 7 days in discovery for validation
    options.KeyManagement.RetentionDuration = TimeSpan.FromDays(7);

    // Don't delete keys after their retention period is over
    options.KeyManagement.DeleteRetiredKeys = false;
});
```

### KeyManagement Options Reference

| Property                             | Default   | Description                                               |
| ------------------------------------ | --------- | --------------------------------------------------------- |
| `Enabled`                            | `true`    | Enable automatic key management                           |
| `SigningAlgorithms`                  | `[RS256]` | Algorithms for which keys are managed                     |
| `RsaKeySize`                         | `2048`    | RSA key size in bits                                      |
| `RotationInterval`                   | 90 days   | Age at which keys stop signing                            |
| `PropagationTime`                    | 14 days   | Time for new keys to propagate to all servers and clients |
| `RetentionDuration`                  | 14 days   | Duration retired keys remain in discovery                 |
| `DeleteRetiredKeys`                  | `true`    | Delete keys after retention period                        |
| `KeyPath`                            | `{ContentRootPath}/keys` | File system path for default key store               |
| `DataProtectKeys`                    | `true`    | Encrypt keys at rest using data protection                |
| `KeyCacheDuration`                   | 24 hours  | Cache duration for keys from store                        |
| `InitializationDuration`             | 5 minutes | Synchronization window on first key creation              |
| `InitializationSynchronizationDelay` | 5 seconds | Delay between retries during initialization               |

### Multiple Signing Algorithms

Configure multiple algorithms to serve clients with different requirements. The first algorithm in the list is the default for signing tokens.

```csharp
options.KeyManagement.SigningAlgorithms = new[]
{
    // RS256 for older clients (with X.509 wrapping)
    new SigningAlgorithmOptions(SecurityAlgorithms.RsaSha256) { UseX509Certificate = true },

    // PS256
    new SigningAlgorithmOptions(SecurityAlgorithms.RsaSsaPssSha256),

    // ES256
    new SigningAlgorithmOptions(SecurityAlgorithms.EcdsaSha256)
};
```

Override the default on a per-client or per-resource basis:

```csharp
// Client level
var client = new Client
{
    AllowedIdentityTokenSigningAlgorithms = { SecurityAlgorithms.RsaSsaPssSha256 }
};

// API Resource level
var api = new ApiResource("invoice")
{
    AllowedAccessTokenSigningAlgorithms = { SecurityAlgorithms.RsaSsaPssSha256 }
};
```

## Key Storage

### Default: File System

The default `FileSystemKeyStore` writes keys to the `KeyPath` directory (defaults to `{ContentRootPath}/keys`). This directory must be:

- Excluded from source control
- Accessible (read/write) to all load-balanced instances if using file-based storage

```csharp
// Program.cs
var idsvrBuilder = builder.Services.AddIdentityServer(options =>
{
    options.KeyManagement.KeyPath = "/home/shared/keys";
});
```

### EntityFramework Store

Use the EF operational store for database-backed key storage:

```csharp
// Program.cs
builder.Services.AddIdentityServer()
    .AddOperationalStore(options =>
    {
        options.ConfigureDbContext = b =>
            b.UseSqlServer(connectionString);
    });
```

### Duende Storage Store (preview)

`AddStorage(...)` + `AddOperationalStorage()` stores signing keys through the Duende Storage layer (`ISigningKeyStore`). See `identityserver-duende-storage`.

### Custom Store

Implement `ISigningKeyStore` for custom storage (e.g., Azure Key Vault, AWS KMS):

```csharp
// Program.cs
builder.Services.AddIdentityServer()
    .AddSigningKeyStore<YourCustomStore>();
```

The store interface methods:

- `LoadKeysAsync` - load all keys (cached for `KeyCacheDuration`)
- `StoreKeyAsync` - persist a new key
- `DeleteKeyAsync` - remove a retired key

## HSM and Cloud KMS

IdentityServer has **no built-in HSM/KMS provider**. Options depend on how the key is exposed:

- **HSM key exposed to .NET** (`X509Certificate2`/`RSA`/`ECDsa` backed by CNG/PKCS#11): register as a static credential with `AddSigningCredential`; signing happens inside the HSM, no private-key export.
- **Remote KMS signing via API**: custom `CryptoProviderFactory` + `SignatureProvider` attached to the `SecurityKey` (signing is synchronous, so async KMS calls block), **or** subclass `DefaultTokenCreationService` and override `CreateJwtAsync` to call the KMS async signing API.
- **Custom `ISigningKeyStore`** only changes where automatic key management stores its (exportable) keys, e.g. a vault. It is not a way to use non-exportable keys.

### Async remote KMS signing (Azure Key Vault example)

All JWTs (access, identity, JWT introspection) go through `ITokenCreationService`.

```csharp
// KeyVaultTokenCreationService.cs
public class KeyVaultTokenCreationService(
    CryptographyClient crypto, TimeProvider timeProvider, IKeyMaterialService keys,
    IdentityServerOptions options, ILogger<DefaultTokenCreationService> logger)
    : DefaultTokenCreationService(timeProvider, keys, options, logger)
{
    protected override async Task<string> CreateJwtAsync(Token token, string payload,
        Dictionary<string, object> headerElements, CancellationToken ct)
    {
        var credential = await Keys.GetSigningCredentialsAsync(token.AllowedSigningAlgorithms, ct);
        headerElements.TryAdd("typ", "JWT");
        headerElements["alg"] = credential.Algorithm;
        headerElements["kid"] = credential.Key.KeyId;

        var header = Base64UrlEncoder.Encode(JsonSerializer.Serialize(headerElements));
        var body = Base64UrlEncoder.Encode(payload);
        var signingInput = $"{header}.{body}";
        var result = await crypto.SignDataAsync(
            new SignatureAlgorithm(credential.Algorithm), Encoding.UTF8.GetBytes(signingInput), ct);
        return $"{signingInput}.{Base64UrlEncoder.Encode(result.Signature)}";
    }
}
```

```csharp
// Program.cs: register the KMS *public* key as the signing credential and disable automatic key management
var publicKey = new RsaSecurityKey(kmsKey.Key.ToRSA(includePrivateParameters: false)) { KeyId = kmsKey.Properties.Version };
builder.Services.AddIdentityServer(o => o.KeyManagement.Enabled = false)
    .AddSigningCredential(new SigningCredentials(publicKey, SecurityAlgorithms.RsaSha256));
builder.Services.AddSingleton(new CryptographyClient(kmsKey.Id, azureCredential));
builder.Services.AddTransient<ITokenCreationService, KeyVaultTokenCreationService>();
```

Caveats: IdentityServer still needs a signing credential (algorithm for `at_hash`/`c_hash`, `id_token_signing_alg_values_supported`, JWKS publishing), so use `AddSigningCredential`, not only `AddValidationKey`. Rotation is your job: publish the new public key ahead of time with `AddValidationKey`, keep the old one until tokens expire. **SAML signing does not use `ITokenCreationService`**; it reads the credential directly and needs a private key, so this approach doesn't cover SAML. Each token costs a KMS network call (latency/rate limits/availability). v7 differences: `IClock` instead of `TimeProvider`, no `CancellationToken` on `CreateJwtAsync`, `GetSigningCredentialsAsync` takes only the algorithms.

## Backing Up Signing Keys

With automatic key management, stored keys are encrypted with ASP.NET Core Data Protection by default, so a key-store backup is only usable together with the Data Protection keys: back up and restore both. The restored key ring is only readable with the same application name (`SetApplicationName`) and access to whatever protects it at rest (certificate / Key Vault). With static keys, back up the certificate and private key with the same protections.

## Responding to a Key Compromise

Rotate immediately; don't wait for the schedule:

1. Add a new signing key and make it active (auto: create new key; static: replace the `AddSigningCredential` credential).
2. Stop publishing/signing with the compromised key. Unlike routine phased rotation, **don't keep the old key as a validation key**. Auto: *delete* the key from the store (retired keys remain published for `RetentionDuration`), then **restart every instance** (keys are cached for `KeyManagement.KeyCacheDuration`). Static: remove it from `AddSigningCredential` and any `AddValidationKey`, redeploy all instances. Confirm every instance's JWKS no longer lists the `kid`.
3. Accept that tokens signed with it become invalid; users may need to sign in again.
4. Revoke refresh tokens/persisted grants issued before removal (all active grants if the exposure window is unknown).
5. Notify relying parties (clients, APIs that cache JWKS, SAML SPs with static certificates).
6. Investigate how it was exposed; review key and Data Protection key storage.
7. **Backups:** treat backups of signing keys as compromised too. Backups of automatic-management signing keys are encrypted with Data Protection, so they only work with the **matching Data Protection keys** and the **same application name** (`SetApplicationName`). Back up and restore both together, and make sure no backup still contains the compromised key.

## Encryption of Keys at Rest

By default, keys are protected at rest using ASP.NET Core Data Protection (`DataProtectKeys = true`). Keep this enabled unless your custom `ISigningKeyStore` already ensures encryption (e.g., Azure Key Vault).

```csharp
// ❌ WRONG: Disabling without alternative encryption
options.KeyManagement.DataProtectKeys = false;

// ✅ CORRECT: Only disable when using a vault that encrypts at rest
options.KeyManagement.DataProtectKeys = false; // OK if using Azure Key Vault via custom ISigningKeyStore
```

### Data Protection Configuration for Production

Data protection must be properly configured for key encryption to work across instances. See [ASP.NET Core Data Protection](https://docs.duendesoftware.com/general/data-protection/) for foundational concepts and troubleshooting.

```csharp
// Program.cs
builder.Services.AddDataProtection()
    .PersistKeysToDbContext<MyDbContext>()        // or PersistKeysToAzureBlobStorage, etc.
    .ProtectKeysWithCertificate(certificate)      // or ProtectKeysWithAzureKeyVault
    .SetApplicationName("My.IdentityServer");
```

### Common Data Protection Problems

| Symptom                                                              | Cause                                             | Fix                                      |
| -------------------------------------------------------------------- | ------------------------------------------------- | ---------------------------------------- |
| `CryptographicException: The key {ID} was not found in the key ring` | Data protection keys not shared across instances  | Configure shared key persistence         |
| `Error unprotecting key with kid {ID}`                               | Keys protected by a different data protection key | Ensure consistent data protection config |
| Keys work locally but fail in deployment                             | Default file-based storage uses ephemeral storage | Use durable, shared storage              |
| Keys break after redeployment                                        | Application name changed or not set               | Set explicit `SetApplicationName()`      |

## Static Key Management

For scenarios where you want explicit control over signing keys or your license does not include automatic key management.

### Disabling Automatic Key Management

```csharp
// Program.cs
var idsvrBuilder = builder.Services.AddIdentityServer(options =>
{
    options.KeyManagement.Enabled = false;
});
```

### Adding Static Signing Keys

```csharp
// Program.cs
var idsvrBuilder = builder.Services.AddIdentityServer();
var key = LoadKeyFromVault(); // your code to load the key
idsvrBuilder.AddSigningCredential(key, SecurityAlgorithms.RsaSha256);
```

Multiple signing keys can be registered. The first one added is the default.

### Adding Validation Keys

Register public keys that should be accepted for token validation (used during key rotation):

```csharp
idsvrBuilder.AddValidationKey(oldKey, SecurityAlgorithms.RsaSha256);
```

### Creating Self-Signed Certificates

```csharp
var name = "MySelfSignedCertificate";

using var rsa = RSA.Create(keySizeInBits: 2048);

var request = new CertificateRequest(
    subjectName: $"CN={name}",
    rsa,
    HashAlgorithmName.SHA256,
    RSASignaturePadding.Pkcs1
);

var certificate = request.CreateSelfSigned(
    DateTimeOffset.Now,
    DateTimeOffset.Now.AddYears(1)
);

var pfxBytes = certificate.Export(X509ContentType.Pfx, password: "password");
File.WriteAllBytes($"{name}.pfx", pfxBytes);
```

### Loading Keys from Disk or Certificate Store

```csharp
// From PFX file
var bytes = File.ReadAllBytes("mycertificate.pfx");
var certificate = X509CertificateLoader.LoadPkcs12(bytes, "password");

// From certificate store
var store = new X509Store(StoreName.My, StoreLocation.CurrentUser);
store.Open(OpenFlags.ReadWrite);
var certificate = store.Certificates.First(c => c.Thumbprint == "<thumbprint>");
```

## Manual Key Rotation (Phased Approach)

When using static keys, rotation must be performed carefully to avoid validation failures.

### Why Phased Rotation is Necessary

1. **Client/API caching** - Clients and APIs cache keys (default: 24 hours). Using a new key immediately means cached clients cannot validate tokens signed with it.
2. **Existing tokens** - Tokens signed with the old key are still valid. Removing the old key immediately invalidates those tokens.

### Phase 1: Announce the New Key

Sign with the old key, publish the new key as a validation key:

```csharp
var idsvrBuilder = builder.Services.AddIdentityServer(options =>
{
    options.KeyManagement.Enabled = false;
});

var oldKey = LoadOldKeyFromVault();
var newKey = LoadNewKeyFromVault();
idsvrBuilder.AddSigningCredential(oldKey, SecurityAlgorithms.RsaSha256);
idsvrBuilder.AddValidationKey(newKey, SecurityAlgorithms.RsaSha256);
```

**Wait:** Until all clients/APIs have refreshed their caches (default 24 hours).

### Phase 2: Start Signing with the New Key

Swap signing and validation keys:

```csharp
var idsvrBuilder = builder.Services.AddIdentityServer(options =>
{
    options.KeyManagement.Enabled = false;
});

var oldKey = LoadOldKeyFromVault();
var newKey = LoadNewKeyFromVault();
idsvrBuilder.AddSigningCredential(newKey, SecurityAlgorithms.RsaSha256);
idsvrBuilder.AddValidationKey(oldKey, SecurityAlgorithms.RsaSha256);
```

**Wait:** Until all tokens signed with the old key have expired (default access token lifetime: 1 hour).

### Phase 3: Remove the Old Key

```csharp
var idsvrBuilder = builder.Services.AddIdentityServer(options =>
{
    options.KeyManagement.Enabled = false;
});

var newKey = LoadNewKeyFromVault();
idsvrBuilder.AddSigningCredential(newKey, SecurityAlgorithms.RsaSha256);
```

## Migrating from Static to Automatic Key Management

This is also a three-phase process where automatic keys gradually replace static keys.

### Phase 1: Enable Automatic Key Management, Keep Signing with Static Key

The static signing credential takes precedence over automatic keys. Automatic key management begins creating and announcing keys in discovery.

```csharp
var idsvrBuilder = builder.Services.AddIdentityServer(options =>
{
    options.KeyManagement.Enabled = true;
});

var oldKey = LoadOldKeyFromVault();
idsvrBuilder.AddSigningCredential(oldKey, SecurityAlgorithms.RsaSha256);
```

**Wait:** Until all APIs and clients have updated their caches with the new automatic keys.

### Phase 2: Switch to Automatic Signing, Keep Static for Validation

Remove the static signing credential; keep it as a validation key:

```csharp
var idsvrBuilder = builder.Services.AddIdentityServer(options =>
{
    options.KeyManagement.Enabled = true;
});

var oldKey = LoadOldKeyFromVault();
idsvrBuilder.AddValidationKey(oldKey, SecurityAlgorithms.RsaSha256);
```

**Wait:** Until all tokens signed with the old static key have expired.

### Phase 3: Remove Static Key Entirely

```csharp
var idsvrBuilder = builder.Services.AddIdentityServer(options =>
{
    options.KeyManagement.Enabled = true;
});
```

## Multi-Instance / Load-Balanced Deployment

### Requirements

| Concern                             | Solution                                            |
| ----------------------------------- | --------------------------------------------------- |
| Key storage shared across instances | Use EF operational store or shared file system      |
| Data protection keys shared         | Configure shared data protection key persistence    |
| Key cache synchronization           | `PropagationTime` handles cache refresh windows     |
| Initialization race condition       | `InitializationDuration` (5 min) allows server sync |

### File System Store in Load-Balanced Environments

All instances need read/write access to the `KeyPath`:

```csharp
options.KeyManagement.KeyPath = "/shared-volume/identity-keys";
```

### Recommended: Database-Backed Store

```csharp
builder.Services.AddIdentityServer()
    .AddOperationalStore(options =>
    {
        options.ConfigureDbContext = b => b.UseSqlServer(connectionString);
    });
```

## OIDC + SAML Shared Signing Keys

When the SAML component is enabled, IdentityServer uses the **same signing credentials** for OIDC tokens and SAML messages — one key store, one rotation schedule. Rotated public keys are published in parallel via the OIDC JWKS endpoint and the SAML IdP metadata during rollover.

### X.509 Requirement (SAML metadata needs certificates)

SAML metadata requires X.509 certificates, not raw keys:

- **Automatic Key Management** — creates RSA keys by default, and the SAML component **auto-wraps** managed RSA keys in self-signed X.509 certificates. You do **not** need to set `UseX509Certificate` just to enable SAML.
- **Static Key Management** — you **must** configure an X.509 signing certificate **with a private key**. A manually registered raw RSA key — including one from `AddDeveloperSigningCredential()` — **cannot** be auto-wrapped for SAML.

### Constraints

- The default SAML signing service supports **RSA only**. `UseX509Certificate` is **not** supported for EC (`ES`) keys.
- For a different certificate, independent rotation, or an external key system, implement a custom `ISamlSigningService`.

### Rotation Knobs (shared with OIDC)

| Knob                | Effect for SAML                                                                                                          |
| ------------------- | ---------------------------------------------------------------------------------------------------------------------- |
| `PropagationTime`   | How long a new managed key is published before it starts signing — set long enough for all SPs to refresh IdP metadata. |
| `RetentionDuration` | Keeps the previous certificate in metadata while SPs may still validate old messages (and old OIDC tokens remain valid). |

Service providers with **statically configured** IdP certificates must update those certs on every rotation.

## Common Pitfalls

1. **`keys` directory in source control** - Contains cryptographic secrets. Add the `keys` directory (under the app content root) to `.gitignore`. If accidentally committed, the keys may be data-protected with development-only data protection keys and fail in production.

2. **Data protection not configured for production** - Default data protection uses machine-specific keys. In containers or multi-instance deployments, keys protected by one instance cannot be read by another. Always configure shared, persistent data protection.

3. **Immediate key rotation** - Switching signing keys without a transition period causes validation failures. Use the phased approach or rely on automatic key management.

4. **Disabling `DataProtectKeys` without alternative** - Turning off key encryption without ensuring your store encrypts at rest exposes signing keys to anyone with storage access.

5. **X.509 certificate expiration confusion** - IdentityServer does not validate X.509 certificate expiration dates. Expired certificates still work for signing. The expiration date is a policy decision, not a technical enforcement.

6. **Not setting `PropagationTime` long enough** - If clients/APIs cache keys longer than your propagation time, new keys may not be in their caches when signing starts. Ensure `PropagationTime` exceeds your longest cache duration.

7. **Mixing up Data Protection keys and signing keys** - These are completely separate. Data Protection uses symmetric encryption for sensitive data at rest. Signing keys use asymmetric cryptography for token signatures. Both must be properly configured.
