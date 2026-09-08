The reason the handler never presents your certificate is that it uses its own internal `HttpClient` for all back-channel calls (the code-for-token exchange, token refresh, and the userinfo request). Unless you replace that client's underlying handler with one configured to send your client certificate, those calls go out over a plain TLS connection with no client cert — which is why the mTLS token endpoint isn't being used the way you expect.

## Supply a back-channel handler that presents the client certificate

Set `options.BackchannelHttpHandler` to a handler that carries your certificate. On modern .NET, `SocketsHttpHandler` with `SslClientAuthenticationOptions.ClientCertificates` is the clean way to do that:

```csharp
using System.Net.Security;
using System.Security.Cryptography.X509Certificates;

var clientCert = X509CertificateLoader.LoadPkcs12(
    File.ReadAllBytes("client.p12"), "password");

builder.Services.AddAuthentication(options =>
{
    options.DefaultScheme = "Cookies";
    options.DefaultChallengeScheme = "oidc";
})
.AddCookie("Cookies")
.AddOpenIdConnect("oidc", options =>
{
    options.Authority = "https://identity.example.com";
    options.ClientId = "mtls.client";
    options.ClientSecret = "secret";
    options.ResponseType = "code";
    options.MapInboundClaims = false;
    options.SaveTokens = true;

    // Present the client certificate on the handler's back-channel calls
    options.BackchannelHttpHandler = new SocketsHttpHandler
    {
        SslOptions = new SslClientAuthenticationOptions
        {
            ClientCertificates = new X509CertificateCollection { clientCert }
        }
    };
});
```

Now the token, refresh, and userinfo requests are made over a mutually-authenticated TLS connection and your certificate is presented.

## A couple of things to verify

- **The certificate must be usable for client authentication** — it needs the client-auth EKU and the private key must be available (loading from a `.p12`/PFX as above includes it).
- **Server trust** — IdentityServer must be configured to accept and require the client certificate for this client, and your host/reverse proxy must forward the certificate through to it.
- **Endpoint/host** — confirm the authority's discovery document points the token endpoint at the host that negotiates mTLS. If IdentityServer exposes mTLS on a different host/port than the regular endpoints, make sure your client is actually reaching that mTLS-enabled listener.

If after wiring up the back-channel handler the certificate still isn't presented, capture the TLS handshake (e.g. with a network trace) to confirm the `CertificateRequest` is being sent by the server and the client is responding with your certificate.
