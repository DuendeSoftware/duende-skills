There are **two** distinct problems to solve, and the stock OIDC handler solves neither on its own:

1. It doesn't present your client certificate on back-channel calls (code redemption, refresh, userinfo, introspection).
2. It reads endpoints from the standard discovery metadata and ignores `mtls_endpoint_aliases`, so it keeps hitting the **non-mTLS** `token_endpoint`.

You fix (1) with a `BackchannelHttpHandler` that carries the certificate, and (2) with a custom `IConfigurationManager<OpenIdConnectConfiguration>` that rewrites the endpoints to their mTLS aliases.

## Step 1 — Present the client certificate on back-channel calls

Use a `SocketsHttpHandler` whose `SslOptions.ClientCertificates` contains your certificate. With mTLS, **no client secret is required** — the certificate *is* the client authentication (`tls_client_auth` / RFC 8705). So drop `ClientSecret` entirely.

```csharp
var clientCert = X509CertificateLoader.LoadPkcs12(File.ReadAllBytes("client.p12"), "password");

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
    // no ClientSecret — the client certificate authenticates the client
    options.ResponseType = "code";
    options.MapInboundClaims = false;
    options.SaveTokens = true;

    // Present the client certificate on ALL back-channel TLS connections
    options.BackchannelHttpHandler = new SocketsHttpHandler
    {
        SslOptions = new SslClientAuthenticationOptions
        {
            ClientCertificates = new X509CertificateCollection { clientCert }
        }
    };
});
```

## Step 2 — Point the handler at `mtls_endpoint_aliases`

Duende publishes a separate set of mTLS endpoints in discovery under `mtls_endpoint_aliases`. The stock handler has no concept of them, so wrap the standard `ConfigurationManager` and rewrite the strongly-typed endpoint slots to the mTLS values:

```csharp
using System.Text.Json;
using Microsoft.IdentityModel.Protocols;
using Microsoft.IdentityModel.Protocols.OpenIdConnect;

public sealed class MtlsConfigurationManager
    : IConfigurationManager<OpenIdConnectConfiguration>
{
    private readonly ConfigurationManager<OpenIdConnectConfiguration> _inner;

    public MtlsConfigurationManager(ConfigurationManager<OpenIdConnectConfiguration> inner)
        => _inner = inner;

    public async Task<OpenIdConnectConfiguration> GetConfigurationAsync(CancellationToken ct)
    {
        var config = await _inner.GetConfigurationAsync(ct);

        if (config.AdditionalData.TryGetValue("mtls_endpoint_aliases", out var raw)
            && raw is JsonElement aliases)
        {
            config.TokenEndpoint =
                aliases.GetProperty("token_endpoint").GetString();
            config.IntrospectionEndpoint =
                aliases.GetProperty("introspection_endpoint").GetString();
            config.DeviceAuthorizationEndpoint =
                aliases.GetProperty("device_authorization_endpoint").GetString();

            // .NET 9+ automatically uses PAR when the server advertises a
            // pushed_authorization_request_endpoint. If you don't rewrite it too,
            // the pushed authorization request goes to the NON-mTLS endpoint and the
            // certificate binding is lost — so rewrite it to the mTLS alias as well.
            config.PushedAuthorizationRequestEndpoint =
                aliases.GetProperty("pushed_authorization_request_endpoint").GetString();

            // revocation has no strongly-typed slot — keep it in AdditionalData
            config.AdditionalData["revocation_endpoint"] =
                aliases.GetProperty("revocation_endpoint").GetString();
        }

        return config;
    }

    public void RequestRefresh() => _inner.RequestRefresh();
}
```

Wire it onto the handler (reusing the mTLS back-channel handler so metadata is also fetched over the right channel if needed):

```csharp
.AddOpenIdConnect("oidc", options =>
{
    // ... options from Step 1 ...

    options.ConfigurationManager = new MtlsConfigurationManager(
        new ConfigurationManager<OpenIdConnectConfiguration>(
            $"{options.Authority}/.well-known/openid-configuration",
            new OpenIdConnectConfigurationRetriever(),
            new HttpDocumentRetriever { RequireHttps = true }));
});
```

## Summary

- **Back-channel cert:** `BackchannelHttpHandler = new SocketsHttpHandler { SslOptions = new SslClientAuthenticationOptions { ClientCertificates = { clientCert } } }`.
- **No secret:** the certificate authenticates the client, so `ClientSecret` is omitted.
- **Endpoint aliasing:** a custom `IConfigurationManager<OpenIdConnectConfiguration>` rewrites `TokenEndpoint`, `IntrospectionEndpoint`, and `DeviceAuthorizationEndpoint` (plus, on .NET 9+, `PushedAuthorizationRequestEndpoint`) to the `mtls_endpoint_aliases` values — otherwise the handler silently calls the non-mTLS endpoints and the token is never certificate-bound.
