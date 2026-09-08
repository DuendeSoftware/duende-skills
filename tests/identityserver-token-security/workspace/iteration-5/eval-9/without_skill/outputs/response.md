# mTLS behind an Nginx reverse proxy

When Nginx terminates TLS, Kestrel no longer performs the TLS handshake, so it can't obtain the client certificate directly. Instead, Nginx passes the client certificate to IdentityServer in an HTTP header, and you use ASP.NET Core's **certificate forwarding** to reconstruct it.

## Nginx side

Configure Nginx to request/verify the client certificate and forward it, for example:

```nginx
ssl_client_certificate /etc/nginx/ca.crt;
ssl_verify_client optional;

location / {
    proxy_pass http://identityserver;
    proxy_set_header X-SSL-CERT $ssl_client_escaped_cert;
}
```

`$ssl_client_escaped_cert` is the client certificate as a URL-encoded PEM string.

## IdentityServer / Kestrel configuration

```csharp
using System.Security.Cryptography.X509Certificates;

var builder = WebApplication.CreateBuilder(args);

// Kestrel must NOT try to negotiate a client certificate — the proxy already terminated TLS
builder.WebHost.ConfigureKestrel(k =>
    k.ConfigureHttpsDefaults(h =>
        h.ClientCertificateMode = ClientCertificateMode.NoCertificate));

// Rebuild the X509Certificate2 from the forwarded header
builder.Services.AddCertificateForwarding(options =>
{
    options.CertificateHeader = "X-SSL-CERT";
    options.HeaderConverter = headerValue =>
    {
        if (string.IsNullOrWhiteSpace(headerValue)) return null!;
        var pem = Uri.UnescapeDataString(headerValue);
        return X509Certificate2.CreateFromPem(pem);
    };
});

builder.Services.AddAuthentication()
    .AddCertificate(options =>
    {
        // Real PKI certificates chain to a CA
        options.AllowedCertificateTypes = CertificateTypes.Chained;
        options.ValidateCertificateUse = true;
    });

builder.Services.AddIdentityServer(options =>
{
    options.MutualTls.Enabled = true;
    options.MutualTls.DomainName = "mtls"; // endpoints on the mtls sub-domain
})
    .AddInMemoryIdentityResources(Config.IdentityResources)
    .AddInMemoryApiScopes(Config.ApiScopes)
    .AddInMemoryClients(Config.Clients)
    .AddMutualTlsSecretValidators();

var app = builder.Build();

// Certificate forwarding must run before authentication
app.UseCertificateForwarding();
app.UseAuthentication();
app.UseAuthorization();
app.UseIdentityServer();

app.Run();
```

Key points:

- **`ClientCertificateMode.NoCertificate`** — Kestrel doesn't ask for a certificate because TLS is terminated at Nginx.
- **`AddCertificateForwarding` + `UseCertificateForwarding()`** — reconstructs the certificate from the `X-SSL-CERT` header, and must be placed *before* `UseAuthentication()` so the certificate is available to the auth handler.
- **`CertificateTypes.Chained`** — production certificates are issued by a CA and chain to it, unlike the self-signed certs you'd use locally.
- **`MutualTls.DomainName = "mtls"`** — puts the mTLS-protected endpoints on the `mtls` sub-domain.

## How clients discover the mTLS endpoint

With the sub-domain strategy the token endpoint used for mTLS is different from the normal one. IdentityServer advertises it in the discovery document under `mtls_endpoint_aliases`, so clients should read it from there:

```csharp
var disco = await client.GetDiscoveryDocumentAsync("https://identity.example.com");
var mtlsTokenEndpoint = disco.MtlsEndpointAliases.TokenEndpoint;
// e.g. https://mtls.identity.example.com/connect/token
```

The client attaches its certificate to the outgoing HTTP connection and posts to that mTLS token endpoint (use `ClientCredentialStyle.PostBody`).
