# Certificate-bound tokens without certificate authentication

Set `AlwaysEmitConfirmationClaim` so IdentityServer binds tokens to the client certificate regardless of how the client authenticated:

```csharp
builder.Services.AddIdentityServer(options =>
{
    options.MutualTls.Enabled = true;
    options.MutualTls.DomainName = "mtls";
    options.MutualTls.AlwaysEmitConfirmationClaim = true;
});

new Client
{
    ClientId = "hybrid_app",
    AllowedGrantTypes = GrantTypes.ClientCredentials,
    ClientSecrets = { new Secret("secret".Sha256()) },   // still a shared secret
    AllowedScopes = { "api1" }
}
```

(Note: it's `options.MutualTls.AlwaysEmitConfirmationClaim`, not a client property. Forgetting it is a common pitfall: without it, `cnf` is only emitted for mTLS-authenticated clients.)

The access token then contains:
```json
{ "cnf": { "x5t#S256": "bwcK0esc3ACC3DB2Y5_lESsXE8o9ltc05O89jdN-dg2" } }
```

Kestrel needs to accept (not require) certs:
```csharp
kestrel.ConfigureHttpsDefaults(h => h.ClientCertificateMode = ClientCertificateMode.AllowCertificate);
```

The client presents any certificate (even self-generated on the fly) on the TLS channel and calls the token endpoint from discovery's `mtls_endpoint_aliases`, using the shared secret in the POST body:

```csharp
var handler = new SocketsHttpHandler();
handler.SslOptions.ClientCertificates = new X509CertificateCollection { cert };
var client = new HttpClient(handler);
var disco = await client.GetDiscoveryDocumentAsync(authority);

var response = await client.RequestClientCredentialsTokenAsync(new ClientCredentialsTokenRequest
{
    Address = disco.MtlsEndpointAliases.TokenEndpoint,
    ClientCredentialStyle = ClientCredentialStyle.PostBody, // not AuthorizationHeader
    ClientId = "hybrid_app",
    ClientSecret = "secret",
    Scope = "api1"
});
```

APIs must validate the binding with middleware (`app.UseConfirmationValidation()` between authentication and authorization) comparing `x5t#S256` to the SHA-256 thumbprint of the TLS client certificate. This approach works for any authentication method, including public clients.
