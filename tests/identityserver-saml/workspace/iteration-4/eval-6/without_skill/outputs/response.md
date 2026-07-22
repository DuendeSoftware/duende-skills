# Configuring IdentityServer SAML for Multi-Node Load-Balanced Deployments

Running IdentityServer (with SAML) across multiple nodes behind a load balancer introduces several challenges around shared state, cryptographic key management, and request correlation. Here's what you need to configure.

## 1. Data Protection Key Ring (Critical)

ASP.NET Core's Data Protection is used internally by IdentityServer to protect tokens, anti-forgery state, and other transient data. By default, keys are stored in memory — each node generates its own keys, so requests routed to different nodes will fail.

**You must configure a shared key store:**

### Option A: Azure Key Vault + Azure Blob Storage
```csharp
builder.Services.AddDataProtection()
    .PersistKeysToAzureBlobStorage(connectionString, "keys-container", "keys.xml")
    .ProtectKeysWithAzureKeyVault(new Uri("https://your-vault.vault.azure.net/keys/your-key"), credential);
```

### Option B: SQL Server / Database
```csharp
builder.Services.AddDataProtection()
    .PersistKeysToDbContext<YourDbContext>();
```

### Option C: Shared File System
```csharp
builder.Services.AddDataProtection()
    .PersistKeysToFileSystem(new DirectoryInfo(@"\\server\share\dp-keys"))
    .SetApplicationName("your-identityserver-app");
```

> **Important:** Set `.SetApplicationName(...)` to the same value on all nodes so they can share keys.

---

## 2. SAML Signing and Encryption Certificates

SAML assertions must be signed with a consistent certificate across all nodes. If each node loads a different certificate, SPs will reject assertions from nodes they haven't seen before.

**Options for consistent certificate access:**

### Windows Certificate Store (shared via Active Directory / deployment)
```csharp
var cert = X509CertificateLoader.LoadPkcs12FromFile("signing.pfx", password);
```

### Centralized certificate store (recommended for cloud)
- Store the certificate in **Azure Key Vault**, **AWS Secrets Manager**, or similar
- All nodes load the same certificate at startup
- Rotate by updating the central store; all nodes pick up the new cert on next load

### Configuration-based (suitable for Kubernetes secrets)
```csharp
var certBytes = Convert.FromBase64String(configuration["Saml:SigningCert"]);
var cert = new X509Certificate2(certBytes, password);
```

---

## 3. IdentityServer Operational Stores (Persisted Grants)

IdentityServer uses grants and tokens that must be shared across nodes. Use the Entity Framework operational store backed by a shared database:

```csharp
builder.Services.AddIdentityServer()
    .AddOperationalStore(options =>
    {
        options.ConfigureDbContext = b => b.UseSqlServer(connectionString);
        options.EnableTokenCleanup = true;
    })
    .AddConfigurationStore(options =>
    {
        options.ConfigureDbContext = b => b.UseSqlServer(connectionString);
    });
```

---

## 4. SAML-Specific State: In-Progress Request Correlation

SAML uses a request/response correlation mechanism (the `InResponseTo` attribute). The IdP stores the pending request ID while waiting for the user to authenticate; the response must reference the same ID.

If this state is stored in memory (default), a user whose authentication flow spans two different nodes will get an error.

**Solution:** Use distributed caching for session/correlation state:

```csharp
// Use Redis for distributed session
builder.Services.AddStackExchangeRedisCache(options =>
{
    options.Configuration = "redis-host:6379";
});

// Use distributed session (required if SAML plugin stores correlation in session)
builder.Services.AddSession(options =>
{
    options.Cookie.IsEssential = true;
    options.Cookie.SameSite = SameSiteMode.None;
    options.Cookie.SecurePolicy = CookieSecurePolicy.Always;
});
```

Also enable sticky sessions (session affinity) on your load balancer as a fallback during authentication flows, or confirm your SAML plugin fully supports distributed state.

---

## 5. Load Balancer Configuration

### SSL/TLS Termination
If your load balancer terminates TLS, IdentityServer must know about the forwarded headers:

```csharp
app.UseForwardedHeaders(new ForwardedHeadersOptions
{
    ForwardedHeaders = ForwardedHeaders.XForwardedFor | ForwardedHeaders.XForwardedProto
});
```

This ensures SAML metadata URLs, ACS URLs, and redirect URIs are generated with the correct `https://` scheme and public hostname.

### Set Correct Public URL
```csharp
builder.Services.AddIdentityServer(options =>
{
    options.IssuerUri = "https://idp.example.com"; // Set explicitly, not derived from request
});
```

---

## 6. SAML Metadata Consistency

Your SAML metadata (published at `/.well-known/saml-configuration` or similar) must be stable and identical across all nodes. Since it includes your signing certificate and entity ID, as long as certificates and configuration are consistent (see above), this should be automatic.

---

## Summary Checklist

| Concern | Solution |
|---------|----------|
| Data Protection keys | Shared persistent store (DB, Azure Blob, file share) |
| SAML signing cert | Central certificate store (Key Vault, secrets manager) |
| IdentityServer grants | SQL Server / EF operational store |
| SAML request correlation | Distributed cache (Redis) or sticky sessions |
| TLS termination at LB | `UseForwardedHeaders` middleware |
| Consistent issuer URL | Explicitly set `options.IssuerUri` |
| App name consistency | `.SetApplicationName(...)` on Data Protection |

Getting Data Protection and the signing certificate right are the two most common failure points in multi-node deployments.
