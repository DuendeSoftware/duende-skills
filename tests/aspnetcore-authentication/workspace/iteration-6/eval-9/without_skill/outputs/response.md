The stock OIDC handler uses its own `Backchannel` `HttpClient` and the standard `token_endpoint`. For mTLS you need to (1) give the backchannel handler your client certificate and (2) use the `mtls_endpoint_aliases` token endpoint from discovery.

```csharp
using System.Security.Cryptography.X509Certificates;
using Microsoft.AspNetCore.Authentication.OpenIdConnect;

var cert = X509CertificateLoader.LoadPkcs12FromFile("client.pfx", "password");

builder.Services.AddAuthentication(o =>
{
    o.DefaultScheme = "cookie";
    o.DefaultChallengeScheme = "oidc";
})
.AddCookie("cookie")
.AddOpenIdConnect("oidc", o =>
{
    o.Authority = "https://identity.example.com";
    o.ClientId = "web.app";
    o.ResponseType = "code";
    o.UsePkce = true;
    o.SaveTokens = true;

    // present client certificate on back-channel calls
    var handler = new HttpClientHandler();
    handler.ClientCertificates.Add(cert);
    o.BackchannelHttpHandler = handler;

    o.Events.OnAuthorizationCodeReceived = ctx => Task.CompletedTask;

    // Switch to mTLS token endpoint alias once configuration is loaded
    o.Events.OnRedirectToIdentityProvider = ctx =>
    {
        return Task.CompletedTask;
    };
    o.Events.OnTokenResponseReceived = ctx => Task.CompletedTask;
});

builder.Services.AddOptions<OpenIdConnectOptions>("oidc").PostConfigure(o =>
{
    o.ConfigurationManager = null; // custom manager can rewrite endpoints
});
```

Steps in the discovery document: read `mtls_endpoint_aliases.token_endpoint` and replace `configuration.TokenEndpoint` with it (e.g. in `OnRedirectToIdentityProvider`, or by supplying a custom `OpenIdConnectConfiguration` post-processing). Client authentication should use `tls_client_auth`/`self_signed_tls_client_auth`, and no client secret is sent. Alternatively, use Duende.AccessTokenManagement, which supports mTLS client credentials.
