# mTLS client authentication for `mtls.client`

## Server (Program.cs)

```csharp
var idsvrBuilder = builder.Services.AddIdentityServer(options =>
{
    options.MutualTls.Enabled = true;
    options.MutualTls.DomainName = "mtls"; // endpoints on the mtls sub-domain
    options.MutualTls.ClientCertificateAuthenticationScheme = "Certificate";
})
.AddInMemoryIdentityResources(Config.IdentityResources)
.AddInMemoryApiScopes(Config.ApiScopes)
.AddInMemoryClients(Config.Clients);

idsvrBuilder.AddMutualTlsSecretValidators();

builder.Services.AddAuthentication()
    .AddCertificate("Certificate", options =>
    {
        options.AllowedCertificateTypes = CertificateTypes.SelfSigned;
        options.ValidateCertificateUse = true;
    });

builder.WebHost.ConfigureKestrel(kestrel =>
{
    kestrel.ConfigureHttpsDefaults(https =>
    {
        // Accept but don't require; the mTLS endpoint enforces the certificate
        https.ClientCertificateMode = ClientCertificateMode.AllowCertificate;
    });
});
```

## Client

```csharp
new Client
{
    ClientId = "mtls.client",
    AllowedGrantTypes = GrantTypes.ClientCredentials,
    AllowedScopes = { "api1" },
    ClientSecrets =
    {
        // Self-issued certificate: matched by thumbprint
        new Secret("ABC123DEF456", "mtls.tb")
        {
            Type = SecretTypes.X509CertificateThumbprint
        }
    }
}
```
Use `X509CertificateThumbprint` for self-issued certs and `X509CertificateName` (distinguished name) for PKI/chained certs.

## Endpoint URL strategies (`MutualTls.DomainName`)

| Value | Layout |
|---|---|
| null/empty | path-based: `https://host/connect/mtls/token` |
| `"mtls"` | sub-domain: `https://mtls.host/connect/token` |
| full domain | dedicated: `https://mtls.example.com/connect/token` |

You need DNS and a TLS certificate covering the `mtls` sub-domain (on .NET 10, `mtls.localhost` resolves automatically for dev).

## Calling it
The mTLS endpoints are published in discovery under `mtls_endpoint_aliases`; clients must use them:

```csharp
var handler = new SocketsHttpHandler();
handler.SslOptions.ClientCertificates = new X509CertificateCollection { new X509Certificate2("client.p12", "password") };
var client = new HttpClient(handler);

var disco = await client.GetDiscoveryDocumentAsync("https://identity.example.com");
var response = await client.RequestClientCredentialsTokenAsync(new ClientCredentialsTokenRequest
{
    Address = disco.MtlsEndpointAliases.TokenEndpoint,
    ClientCredentialStyle = ClientCredentialStyle.PostBody, // AuthorizationHeader doesn't work with mTLS
    ClientId = "mtls.client",
    Scope = "api1"
});
```

The access token will carry `cnf: { "x5t#S256": "..." }`; APIs must compare it to the TLS client certificate thumbprint (custom `UseConfirmationValidation` middleware).
