# Configuring Pushed Authorization Requests (PAR)

PAR (Pushed Authorization Requests) moves authorization parameters from the front channel (browser URL) to the back channel (direct HTTP POST). This prevents parameter leakage and tampering.

## Updated Program.cs

```csharp
using Duende.IdentityServer.Models;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddIdentityServer(options =>
{
    // Require PAR globally
    options.PushedAuthorization.Required = true;

    // Set global PAR lifetime to 5 minutes
    options.PushedAuthorization.Lifetime = TimeSpan.FromMinutes(5);
})
    .AddInMemoryIdentityResources(Config.IdentityResources)
    .AddInMemoryApiScopes(Config.ApiScopes)
    .AddInMemoryClients(Config.Clients);

var app = builder.Build();

app.UseIdentityServer();
app.UseAuthorization();

app.Run();

public static class Config
{
    public static IEnumerable<IdentityResource> IdentityResources =>
    [
        new IdentityResources.OpenId(),
        new IdentityResources.Profile()
    ];

    public static IEnumerable<ApiScope> ApiScopes =>
    [
        new ApiScope("api1", "My API")
    ];

    public static IEnumerable<Client> Clients =>
    [
        new Client
        {
            ClientId = "machine_client",
            AllowedGrantTypes = GrantTypes.ClientCredentials,
            ClientSecrets = { new Secret("secret".Sha256()) },
            AllowedScopes = { "api1" }
        },
        new Client
        {
            ClientId = "banking_app",
            AllowedGrantTypes = GrantTypes.Code,
            RequirePkce = true,
            ClientSecrets = { new Secret("banking_secret".Sha256()) },
            RedirectUris = { "https://banking.example.com/callback" },
            AllowedScopes = { "openid", "profile", "api1" },
            AllowOfflineAccess = true,

            // Require PAR for this client
            RequirePushedAuthorization = true,

            // Override global lifetime to 15 minutes for this client
            PushedAuthorizationLifetime = 900
        }
    ];
}
```

## How PAR Works

1. The client POSTs authorization parameters to the PAR endpoint (`/connect/par`).
2. The server returns a `request_uri` reference.
3. The client redirects the browser to `/connect/authorize?client_id=...&request_uri=...` — only the reference, not the actual parameters.
4. IdentityServer resolves the stored parameters and processes the request.

## Configuration Details

- `PushedAuthorization.Required = true` enforces PAR for all clients globally.
- `PushedAuthorization.Lifetime` controls how long the pushed request is valid.
- Per-client `RequirePushedAuthorization` can require PAR for specific clients when the global setting is false.
- Per-client `PushedAuthorizationLifetime` overrides the global lifetime — useful for clients with complex authentication flows (MFA, consent) that need more time.
