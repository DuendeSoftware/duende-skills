# Certificate-bound tokens without cert authentication

Keep the shared secret for authentication, and force the confirmation (`cnf`) claim:

```csharp
builder.Services.AddIdentityServer(options =>
{
    options.MutualTls.Enabled = true;
    options.MutualTls.DomainName = "mtls";
})
.AddInMemoryClients(Config.Clients);

new Client
{
    ClientId = "hybrid_app",
    AllowedGrantTypes = GrantTypes.ClientCredentials,
    ClientSecrets = { new Secret("secret".Sha256()) },   // still shared secret
    AllowedScopes = { "api1" },
    AlwaysEmitConfirmationClaim = true
}
```

Normally the `cnf` claim with `x5t#S256` is only emitted when the client authenticated via mTLS. `AlwaysEmitConfirmationClaim = true` makes IdentityServer add it whenever a client certificate is presented on the request, even if authentication used a secret.

The client must call the token endpoint on the mTLS endpoint (`https://mtls.example.com/connect/token`) so a certificate is presented, while still sending `client_id`/`client_secret`. Kestrel needs `ClientCertificateMode.AllowCertificate`, and the API must validate the `cnf` claim against the cert presented on each request (compare SHA-256 thumbprint, base64url).
