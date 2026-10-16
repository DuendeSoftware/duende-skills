The stock handler does two things wrong for mTLS: it doesn't present your certificate on back-channel calls, and it doesn't understand `mtls_endpoint_aliases`, so it calls the standard `token_endpoint`. You need both fixes.

### Step 1 — present the client certificate

```csharp
var clientCert = X509CertificateLoader.LoadPkcs12(File.ReadAllBytes("client.p12"), "password");

.AddOpenIdConnect("oidc", options =>
{
    options.Authority = "https://identity.example.com";
    options.ClientId = "mtls.client";
    // no ClientSecret: the certificate authenticates the client
    options.ResponseType = "code";
    options.MapInboundClaims = false;
    options.SaveTokens = true;

    options.BackchannelHttpHandler = new SocketsHttpHandler
    {
        SslOptions = new SslClientAuthenticationOptions
        {
            ClientCertificates = new X509CertificateCollection { clientCert }
        }
    };
});
```

### Step 2 — rewrite endpoints to the mTLS aliases

```csharp
public sealed class MtlsConfigurationManager : IConfigurationManager<OpenIdConnectConfiguration>
{
    private readonly ConfigurationManager<OpenIdConnectConfiguration> _inner;
    public MtlsConfigurationManager(ConfigurationManager<OpenIdConnectConfiguration> inner) => _inner = inner;

    public async Task<OpenIdConnectConfiguration> GetConfigurationAsync(CancellationToken ct)
    {
        var config = await _inner.GetConfigurationAsync(ct);

        if (config.AdditionalData.TryGetValue("mtls_endpoint_aliases", out var raw)
            && raw is JsonElement aliases)
        {
            config.TokenEndpoint = aliases.GetProperty("token_endpoint").GetString();
            config.IntrospectionEndpoint = aliases.GetProperty("introspection_endpoint").GetString();
            config.DeviceAuthorizationEndpoint = aliases.GetProperty("device_authorization_endpoint").GetString();
            // .NET 9+ auto-uses PAR when advertised; rewrite it too or the certificate binding is lost
            config.PushedAuthorizationRequestEndpoint = aliases.GetProperty("pushed_authorization_request_endpoint").GetString();
            config.AdditionalData["revocation_endpoint"] = aliases.GetProperty("revocation_endpoint").GetString();
        }
        return config;
    }

    public void RequestRefresh() => _inner.RequestRefresh();
}

options.ConfigurationManager = new MtlsConfigurationManager(
    new ConfigurationManager<OpenIdConnectConfiguration>(
        $"{options.Authority}/.well-known/openid-configuration",
        new OpenIdConnectConfigurationRetriever(),
        new HttpDocumentRetriever { RequireHttps = true }));
```

Important on .NET 9+: the handler automatically uses PAR if the server advertises `pushed_authorization_request_endpoint`, so that endpoint must be rewritten to its mTLS alias as well, otherwise the pushed request goes to the non-mTLS endpoint and certificate binding is lost.
