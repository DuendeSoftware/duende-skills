IdentityServer has **no built-in HSM/KMS provider**, so you integrate by doing the signing call to Key Vault yourself. A custom `ISigningKeyStore` is **not** the answer: it only changes where automatic key management stores its (exportable) keys. For a non-exportable Key Vault key, register the *public* key as the credential and sign remotely.

### OIDC / JWTs: custom token creation service

All JWTs (access, identity, JWT introspection) go through `ITokenCreationService`:

```csharp
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
// Program.cs
var publicKey = new RsaSecurityKey(kmsKey.Key.ToRSA(includePrivateParameters: false))
    { KeyId = kmsKey.Properties.Version };

builder.Services.AddIdentityServer(o => o.KeyManagement.Enabled = false)
    .AddSigningCredential(new SigningCredentials(publicKey, SecurityAlgorithms.RsaSha256));

builder.Services.AddSingleton(new CryptographyClient(kmsKey.Id, azureCredential));
builder.Services.AddTransient<ITokenCreationService, KeyVaultTokenCreationService>();
```

Why a credential at all: IdentityServer still needs it for the algorithm (`at_hash`/`c_hash`), `id_token_signing_alg_values_supported`, and JWKS publishing. Use `AddSigningCredential`, not only `AddValidationKey`.

Caveats: signing is a network call per token (latency, rate limits, availability). Rotation is manual: publish the new public key ahead of time via `AddValidationKey`, keep the old one until tokens expire. (v7 differences: `IClock`, no `CancellationToken` on `CreateJwtAsync`.)

### SAML: this approach does NOT cover it

SAML signing doesn't use `ITokenCreationService`; it reads the signing credential directly and **needs a private key**, and SAML metadata needs an X.509 certificate. Options:
- If the HSM key is exposed to .NET as an `X509Certificate2` with a CNG/PKCS#11-backed private key, register it with `AddSigningCredential`; signing happens inside the HSM with no export.
- Otherwise implement a custom `ISamlSigningService` that signs via Key Vault and supplies the certificate for metadata. The default SAML service is RSA only.

Since OIDC and SAML share one credential store/rotation schedule, plan rotation (`AddValidationKey` overlap, SP metadata refresh) for both.
