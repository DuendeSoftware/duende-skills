# Configuring Pushed Authorization Requests (PAR)

PAR moves authorization parameters from the front channel (browser redirect URLs) to the back channel (direct HTTP POST to a dedicated endpoint), preventing parameter leakage and tampering.

## Updated Program.cs

```csharp
using Duende.IdentityServer.Models;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddIdentityServer(options =>
{
    // Require PAR globally
    options.PushedAuthorization.Required = true;

    // PAR request lifetime: 5 minutes (in seconds, as int)
    options.PushedAuthorization.Lifetime = 300;
})
    .AddInMemoryIdentityResources(Config.IdentityResources)
    .AddInMemoryApiScopes(Config.ApiScopes)
    .AddInMemoryClients(new List<Client>
    {
        // Existing clients...
        new Client
        {
            ClientId = "machine_client",
            AllowedGrantTypes = GrantTypes.ClientCredentials,
            ClientSecrets = { new Secret("secret".Sha256()) },
            AllowedScopes = { "api1" }
        },
        new Client
        {
            ClientId = "web_app",
            AllowedGrantTypes = GrantTypes.Code,
            RequirePkce = true,
            ClientSecrets = { new Secret("web_secret".Sha256()) },
            RedirectUris = { "https://webapp.example.com/callback" },
            AllowedScopes = { "openid", "profile", "api1" },
            AllowOfflineAccess = true
        },
        // Banking app with PAR override
        new Client
        {
            ClientId = "banking_app",
            AllowedGrantTypes = GrantTypes.Code,
            RequirePkce = true,
            ClientSecrets = { new Secret("banking_secret".Sha256()) },
            RedirectUris = { "https://banking.example.com/callback" },
            AllowedScopes = { "openid", "profile", "api1" },

            // PAR required for this client (also enforced globally, but explicit)
            RequirePushedAuthorization = true,

            // Override global lifetime to 15 minutes for this client
            PushedAuthorizationLifetime = 900
        }
    });

var app = builder.Build();

app.UseIdentityServer();
app.UseAuthorization();

app.Run();
```

## Configuration Explained

### Global Settings
- **`PushedAuthorization.Required = true`** — All clients must use PAR. Any authorize request without a `request_uri` from the PAR endpoint is rejected.
- **`PushedAuthorization.Lifetime = 300`** — PAR requests expire after 5 minutes (300 seconds). This is an `int`, not a `TimeSpan`. The default is 600 (10 minutes).

### Per-Client Override
- **`RequirePushedAuthorization = true`** — Redundant here since PAR is required globally, but explicit for clarity. Useful when the global setting is `false` and you want specific clients to require PAR.
- **`PushedAuthorizationLifetime = 900`** — Overrides the global 5-minute lifetime to 15 minutes for this client. This gives users more time to complete the authentication flow (MFA, consent, etc.).

### Edition Requirements
PAR requires **Business or Enterprise Edition** of Duende IdentityServer (version >= 7.0). In the Starter edition, PAR requests are not processed. You can disable the endpoint in discovery:

```csharp
options.Endpoints.EnablePushedAuthorizationEndpoint = false;
```

### How PAR Works
1. Client POSTs authorization parameters to `/connect/par`
2. IdentityServer validates and stores the parameters, returns a `request_uri`
3. Client redirects the user to `/connect/authorize?client_id=banking_app&request_uri=urn:ietf:params:oauth:request_uri:...`
4. IdentityServer looks up the stored parameters and proceeds with normal authorization
