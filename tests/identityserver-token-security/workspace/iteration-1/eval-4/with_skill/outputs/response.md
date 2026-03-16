# Configuring Pushed Authorization Requests (PAR)

PAR moves authorization parameters from the front channel (browser redirect URL) to the back channel (direct HTTP POST to the PAR endpoint). This prevents parameter leakage and tampering in the browser URL bar.

**Important:** PAR requires **Duende IdentityServer Business or Enterprise Edition**, version **>= 7.0**.

## Updated Program.cs

```csharp
// Program.cs
using Duende.IdentityServer.Models;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddIdentityServer(options =>
{
    // Require PAR globally — all clients must use the PAR endpoint
    options.PushedAuthorization.Required = true;

    // Lifetime of pushed authorization requests: 5 minutes (in seconds, as int)
    options.PushedAuthorization.Lifetime = 300;
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

            // Require PAR for this specific client (redundant here since global is true,
            // but explicit for clarity and protects against global setting change)
            RequirePushedAuthorization = true,

            // Override global lifetime to 15 minutes (in seconds) for this client
            // Banking users may need more time for MFA and consent
            PushedAuthorizationLifetime = 900
        }
    ];
}
```

## How PAR Works

1. **Client POSTs to PAR endpoint**: Instead of putting all authorization parameters in the browser redirect URL, the client sends them directly to `POST /connect/par` (back channel).
2. **Server returns a `request_uri`**: IdentityServer stores the parameters and returns a short-lived `request_uri` identifier.
3. **Client redirects with `request_uri`**: The browser redirect to `/connect/authorize` only includes `client_id` and `request_uri` — no sensitive parameters in the URL.
4. **Server resolves parameters**: IdentityServer looks up the stored parameters using the `request_uri` and processes the authorization request normally.

## Key Configuration Details

- `PushedAuthorization.Lifetime` is an **`int` in seconds**, not a `TimeSpan`. This is different from many other ASP.NET Core lifetime configurations.
- `PushedAuthorization.Required = true` enforces PAR globally. Without it, PAR is optional (clients can choose to use it if the endpoint is available).
- Per-client `RequirePushedAuthorization` can require PAR for specific clients even when the global setting is `false`.
- Per-client `PushedAuthorizationLifetime` overrides the global lifetime for that client. This is useful when some clients need more time (e.g., banking apps with complex MFA flows).

## .NET 9+ Client Configuration

```csharp
// Client-side Program.cs
builder.Services.AddAuthentication(...)
    .AddCookie()
    .AddOpenIdConnect("oidc", oidcOptions =>
    {
        // .NET 9+ supports PAR natively
        // UseIfAvailable is the default; use Require to enforce
        oidcOptions.PushedAuthorizationBehavior = PushedAuthorizationBehavior.Require;
    });
```

## Why PAR Matters

- **Security**: Authorization parameters (scopes, claims, login hints containing PII) are never exposed in browser URLs.
- **Integrity**: Parameters cannot be tampered with by an attacker modifying the redirect URL.
- **Compliance**: PAR is required by the FAPI 2.0 Security Profile for open banking and similar high-value scenarios.
- **Practicality**: Avoids URL length limits when authorization requests carry large parameter sets.
