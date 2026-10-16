# mTLS client authentication in IdentityServer

## 1. Enable mTLS and endpoints on the `mtls` subdomain

```csharp
builder.Services.AddIdentityServer(options =>
{
    options.MutualTls.Enabled = true;
    options.MutualTls.DomainName = "mtls";    // https://mtls.yourdomain.com
    options.MutualTls.ClientCertificateAuthenticationScheme = "Certificate";
})
.AddInMemoryIdentityResources(Config.IdentityResources)
.AddInMemoryApiScopes(Config.ApiScopes)
.AddInMemoryClients(Config.Clients)
.AddMutualTlsSecretValidators();  // thumbprint/name validators
```

`DomainName` with a single label (no dots) = sub-domain strategy; a full domain means separate domain; leaving it empty uses the path `/connect/mtls`.

Kestrel must request client certs and the Certificate auth scheme must be registered:

```csharp
builder.WebHost.ConfigureKestrel(k =>
    k.ConfigureHttpsDefaults(h =>
    {
        h.ClientCertificateMode = ClientCertificateMode.AllowCertificate;
        h.AllowAnyClientCertificate();
    }));

builder.Services.AddAuthentication()
    .AddCertificate("Certificate", o =>
    {
        o.AllowedCertificateTypes = CertificateTypes.All;
        o.RevocationMode = X509RevocationMode.NoCheck; // use proper chain validation in production
    });
```
You need a wildcard/SAN certificate covering `mtls.yourdomain.com`.

## 2. Client

```csharp
new Client
{
    ClientId = "mtls.client",
    AllowedGrantTypes = GrantTypes.ClientCredentials,
    ClientSecrets =
    {
        new Secret("ABC123DEF456")
        {
            Type = IdentityServerConstants.SecretTypes.X509CertificateThumbprint
        }
    },
    AllowedScopes = { "api1" }
}
```
(For subject-name matching use `X509CertificateName`.)

Clients call the token endpoint on `https://mtls.yourdomain.com/connect/token`, presenting the certificate. Discovery lists them under `mtls_endpoint_aliases`. To bind tokens to the cert (`cnf.x5t#S256`), set `AlwaysEmitConfirmationClaim = true` or it's emitted automatically for mTLS-authenticated clients.
