# mTLS token binding *without* certificate-based client authentication

You can bind an access token to a client certificate while still authenticating the client with an ordinary **shared secret**. The switch that does this is `MutualTls.AlwaysEmitConfirmationClaim`. When enabled, IdentityServer embeds the certificate confirmation (`cnf` with `x5t#S256`) into the access token based on the TLS client certificate — completely independent of how the client authenticated.

## IdentityServer configuration (`Program.cs`)

```csharp
var builder = WebApplication.CreateBuilder(args);

builder.Services.AddIdentityServer(options =>
{
    options.MutualTls.Enabled = true;

    // Emit the cnf/x5t#S256 confirmation claim from the TLS client certificate
    // even when the certificate is NOT used for client authentication.
    options.MutualTls.AlwaysEmitConfirmationClaim = true;
})
    .AddInMemoryIdentityResources(Config.IdentityResources)
    .AddInMemoryApiScopes(Config.ApiScopes)
    .AddInMemoryClients(Config.Clients);

var app = builder.Build();
app.UseIdentityServer();
app.UseAuthorization();
app.Run();
```

## Client configuration — standard shared secret

`hybrid_app` keeps normal shared-secret authentication. There is **no** `X509Certificate*` secret here — the certificate is used only for token binding, not for proving client identity:

```csharp
new Duende.IdentityServer.Models.Client
{
    ClientId = "hybrid_app",
    AllowedGrantTypes = Duende.IdentityServer.Models.GrantTypes.ClientCredentials,
    AllowedScopes = { "api1" },

    // Ordinary shared secret — NOT a certificate secret
    ClientSecrets = { new Duende.IdentityServer.Models.Secret("hybrid_secret".Sha256()) }
}
```

## What happens and what the client must do

- The client authenticates with its **shared secret** at the token endpoint as usual.
- Because `AlwaysEmitConfirmationClaim = true`, IdentityServer takes the certificate presented on the **TLS channel** and adds a `cnf` claim containing the SHA-256 thumbprint of that certificate to the issued access token:

  ```json
  {
    "cnf": { "x5t#S256": "bwcK0esc3ACC3DB2Y5_lESsXE8o9ltc05O89jdN-dg2" }
  }
  ```

- **The client must therefore still present a TLS client certificate when calling the token endpoint** — even though that certificate is *not* checked as a client secret. Without a certificate on the TLS channel there is nothing to bind, and no `cnf` claim will be emitted.
- To get the certificate onto the channel, the client calls the mTLS-flavored token endpoint (published under `mtls_endpoint_aliases` in discovery) and attaches its certificate to the HTTP handler. Since it's not authenticating with the cert, it can even create a certificate on the fly.

## Downstream API

Your APIs then enforce the binding by comparing the `x5t#S256` value in the token's `cnf` claim against the SHA-256 thumbprint of the certificate on the incoming TLS connection (typically via a confirmation-validation middleware after `UseAuthentication()`). A stolen bearer token is useless to an attacker who cannot also present the bound certificate.

This pattern (certificate binding decoupled from certificate authentication) works with any authentication method — including **public clients** — because the binding is driven purely by the TLS certificate plus `AlwaysEmitConfirmationClaim`, not by the client's credentials.
