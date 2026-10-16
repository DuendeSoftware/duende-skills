# mTLS behind an Nginx reverse proxy (sub-domain strategy)

Nginx terminates TLS, so Kestrel never sees the client certificate. Nginx must forward it in a header, and the app must use certificate forwarding.

## Nginx
```nginx
server {
    listen 443 ssl;
    server_name mtls.example.com;
    ssl_verify_client optional;
    ssl_client_certificate /etc/ssl/ca.crt;

    location / {
        proxy_pass http://identityserver:5000;
        proxy_set_header Host $host;
        # Overwrite on every request so clients can't spoof it
        proxy_set_header X-SSL-CERT $ssl_client_escaped_cert;
    }
}
```
Security: the proxy must strip/overwrite the certificate header on all inbound requests.

## IdentityServer host

```csharp
builder.WebHost.ConfigureKestrel(k =>
    k.ConfigureHttpsDefaults(h => h.ClientCertificateMode = ClientCertificateMode.NoCertificate));

builder.Services.AddCertificateForwarding(options =>
{
    options.CertificateHeader = "X-SSL-CERT";
    options.HeaderConverter = headerValue =>
    {
        if (string.IsNullOrWhiteSpace(headerValue)) return null!;
        var pem = Uri.UnescapeDataString(headerValue);   // Nginx: URL-encoded PEM
        return X509Certificate2.CreateFromPem(pem);
    };
});

var idsvr = builder.Services.AddIdentityServer(options =>
{
    options.MutualTls.Enabled = true;
    options.MutualTls.DomainName = "mtls";
    options.MutualTls.ClientCertificateAuthenticationScheme = "Certificate";
});
idsvr.AddMutualTlsSecretValidators();

builder.Services.AddAuthentication()
    .AddCertificate("Certificate", o =>
        o.AllowedCertificateTypes = CertificateTypes.Chained); // production PKI certs are chained

var app = builder.Build();
app.UseCertificateForwarding(); // MUST come before UseAuthentication()
app.UseAuthentication();
app.UseIdentityServer();
app.UseAuthorization();
```

Header conventions: IIS `X-ARR-ClientCert` (base64 DER); Nginx `X-SSL-CERT` (`$ssl_client_escaped_cert`, URL-encoded PEM); Apache `X-SSL-CERT` (PEM).

## Discovery
With `DomainName = "mtls"` endpoints live at `https://mtls.example.com/connect/token` etc. They're published in the discovery document under `mtls_endpoint_aliases`; clients must read them from there instead of the standard endpoints:

```csharp
var tokenEndpoint = disco.MtlsEndpointAliases?.TokenEndpoint;
```
and should use `ClientCredentialStyle.PostBody` (the default Authorization header style does not work with mTLS). DNS and the TLS certificate must cover `mtls.example.com`.
