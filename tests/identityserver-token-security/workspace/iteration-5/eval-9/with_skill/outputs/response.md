# mTLS behind an Nginx reverse proxy (production)

When Nginx terminates TLS, Kestrel never sees the raw TLS handshake, so it can't negotiate the client certificate itself. The pattern is: Nginx validates/passes the client certificate in a **request header**, and IdentityServer uses **certificate forwarding** to turn that header back into a real `X509Certificate2`.

## 1. mTLS sub-domain strategy

Keep the mTLS-protected endpoints on the `mtls` sub-domain:

```csharp
builder.Services.AddIdentityServer(options =>
{
    options.MutualTls.Enabled = true;
    options.MutualTls.DomainName = "mtls"; // https://mtls.<host>/connect/token
    options.MutualTls.ClientCertificateAuthenticationScheme = "Certificate";
})
    .AddInMemoryIdentityResources(Config.IdentityResources)
    .AddInMemoryApiScopes(Config.ApiScopes)
    .AddInMemoryClients(Config.Clients)
    .AddMutualTlsSecretValidators();
```

## 2. Kestrel does NOT negotiate the certificate

Because the proxy terminates TLS, Kestrel must not ask for a client certificate:

```csharp
builder.WebHost.ConfigureKestrel(k =>
    k.ConfigureHttpsDefaults(h =>
        h.ClientCertificateMode = ClientCertificateMode.NoCertificate));
```

## 3. Certificate forwarding — turn the proxy header into a certificate

Nginx forwards the client cert (with `proxy_set_header X-SSL-CERT $ssl_client_escaped_cert;`) as a URL-encoded PEM. Configure `AddCertificateForwarding` to decode it, and use `CertificateTypes.Chained` because production PKI certificates are chained (not self-signed):

```csharp
using System.Security.Cryptography.X509Certificates;

builder.Services.AddCertificateForwarding(options =>
{
    options.CertificateHeader = "X-SSL-CERT"; // must match the Nginx header
    options.HeaderConverter = headerValue =>
    {
        if (string.IsNullOrWhiteSpace(headerValue)) return null!;
        // Nginx $ssl_client_escaped_cert is URL-encoded PEM
        var pem = Uri.UnescapeDataString(headerValue);
        return X509Certificate2.CreateFromPem(pem);
    };
});

builder.Services.AddAuthentication()
    .AddCertificate("Certificate", options =>
    {
        // Production PKI certificates are chained, not self-signed
        options.AllowedCertificateTypes = CertificateTypes.Chained;
        options.ValidateCertificateUse = true;
    });
```

## 4. Pipeline order — forwarding BEFORE authentication

`UseCertificateForwarding()` must run **before** `UseAuthentication()`, so the forwarded certificate is present when the certificate authentication handler runs:

```csharp
var app = builder.Build();

app.UseCertificateForwarding();   // MUST come before UseAuthentication()
app.UseAuthentication();
app.UseAuthorization();

app.UseIdentityServer();

app.Run();
```

## 5. How clients discover the mTLS token endpoint

Clients must not assume the standard `/connect/token`. The mTLS endpoints are published in discovery under `mtls_endpoint_aliases`. Read them from `disco.MtlsEndpointAliases`:

```csharp
var disco = await client.GetDiscoveryDocumentAsync("https://identity.example.com");
var mtlsTokenEndpoint = disco.MtlsEndpointAliases?.TokenEndpoint;
// e.g. https://mtls.identity.example.com/connect/token

var response = await client.RequestClientCredentialsTokenAsync(new ClientCredentialsTokenRequest
{
    Address = mtlsTokenEndpoint,
    ClientCredentialStyle = ClientCredentialStyle.PostBody, // AuthorizationHeader doesn't work with mTLS
    ClientId = "mtls.client",
    Scope = "api1"
});
```

## 6. ⚠️ Security: strip the inbound certificate header

The proxy **must strip or overwrite** the certificate header (`X-SSL-CERT`) on every inbound request before setting its own value. Otherwise a client could simply send `X-SSL-CERT: <some cert>` directly and spoof a certificate it doesn't actually possess on the TLS channel. In Nginx, always assign `proxy_set_header X-SSL-CERT $ssl_client_escaped_cert;` (which overwrites any client-supplied value) — never pass through a client-provided header.

## Nginx header reference

| Proxy | Header | Value format |
| --- | --- | --- |
| Nginx | `X-SSL-CERT` | `$ssl_client_escaped_cert` (URL-encoded PEM) |
| IIS | `X-ARR-ClientCert` | base64 DER |
| Apache | `X-SSL-CERT` | `%{SSL_CLIENT_CERT}s` (PEM) |
