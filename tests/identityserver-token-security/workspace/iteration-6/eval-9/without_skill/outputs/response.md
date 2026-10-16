# mTLS behind Nginx (TLS termination)

Since Nginx terminates TLS, IdentityServer never sees the client cert. Nginx must request it and forward it in a header; IdentityServer's host must read it.

## Nginx
```nginx
server {
    listen 443 ssl;
    server_name mtls.example.com;
    ssl_certificate     /etc/ssl/wildcard.crt;
    ssl_certificate_key /etc/ssl/wildcard.key;
    ssl_client_certificate /etc/ssl/ca.crt;
    ssl_verify_client optional_no_ca;     # or 'optional' with a CA

    location / {
        proxy_pass http://identityserver:5000;
        proxy_set_header Host $host;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header X-SSL-CERT $ssl_client_escaped_cert;
    }
}
```
Always overwrite the header so clients can't spoof it, and only trust the proxy's network.

## IdentityServer host
```csharp
builder.Services.AddCertificateForwarding(o =>
{
    o.CertificateHeader = "X-SSL-CERT";
    o.HeaderConverter = raw =>
        X509Certificate2.CreateFromPem(Uri.UnescapeDataString(raw));
});

builder.Services.AddAuthentication().AddCertificate("Certificate", o =>
    o.AllowedCertificateTypes = CertificateTypes.All);

builder.Services.AddIdentityServer(o =>
{
    o.MutualTls.Enabled = true;
    o.MutualTls.DomainName = "mtls";
    o.MutualTls.ClientCertificateAuthenticationScheme = "Certificate";
}).AddMutualTlsSecretValidators();

var app = builder.Build();
app.UseForwardedHeaders();
app.UseCertificateForwarding();   // before UseAuthentication / UseIdentityServer
app.UseIdentityServer();
```

## Discovery
Clients read `https://identity.example.com/.well-known/openid-configuration`; the `mtls_endpoint_aliases` object lists `token_endpoint`, `revocation_endpoint`, `introspection_endpoint`, etc. on `https://mtls.example.com/connect/...`. Clients using mTLS auth must call those aliases. Ensure the cert covers `mtls.example.com` and DNS points to Nginx.
