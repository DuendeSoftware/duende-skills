# Configuring Pushed Authorization Requests (PAR)

PAR moves authorization parameters from the front channel (browser redirect URLs) to the back channel (direct HTTP POST), preventing parameter leakage and tampering.

**PAR requires Business or Enterprise edition, version >= 7.0.**

## Global Server Configuration

```csharp
var builder = WebApplication.CreateBuilder(args);

builder.Services.AddIdentityServer(options =>
{
    // Require PAR globally — all clients must use PAR
    options.PushedAuthorization.Required = true;
    
    // Lifetime of pushed authorization requests: 5 minutes (300 seconds)
    // Note: this is an int (seconds), NOT a TimeSpan
    options.PushedAuthorization.Lifetime = 300;
})
    .AddInMemoryIdentityResources(Config.IdentityResources)
    .AddInMemoryApiScopes(Config.ApiScopes)
    .AddInMemoryClients(new[]
    {
        // Existing clients...
        new Client
        {
            ClientId = "machine_client",
            AllowedGrantTypes = GrantTypes.ClientCredentials,
            ClientSecrets = { new Secret("secret".Sha256()) },
            AllowedScopes = { "api1" }
        },
        // Banking app with custom PAR lifetime
        new Client
        {
            ClientId = "banking_app",
            AllowedGrantTypes = GrantTypes.Code,
            RequirePkce = true,
            ClientSecrets = { new Secret("banking_secret".Sha256()) },
            RedirectUris = { "https://banking.example.com/callback" },
            AllowedScopes = { "openid", "profile", "api1" },
            
            // Per-client PAR requirement
            RequirePushedAuthorization = true,
            
            // Override global lifetime to 15 minutes (900 seconds)
            PushedAuthorizationLifetime = 900
        }
    });

var app = builder.Build();
app.UseIdentityServer();
app.UseAuthorization();
app.Run();
```

## Configuration Details

### Global settings (`options.PushedAuthorization`)

| Property | Value | Description |
|---|---|---|
| `Required` | `true` | All clients must use PAR. The authorize endpoint rejects requests without a `request_uri`. |
| `Lifetime` | `300` | Pushed authorization requests expire after 5 minutes (300 seconds). This is an `int`, not a `TimeSpan`. |

### Per-client settings (on the `banking_app` client)

| Property | Value | Description |
|---|---|---|
| `RequirePushedAuthorization` | `true` | This specific client must use PAR (redundant here since global is already true, but explicit). |
| `PushedAuthorizationLifetime` | `900` | Overrides the global 300s to 15 minutes for this client. Banking flows may involve longer MFA or approval steps. |

## How PAR Works

1. The client sends authorization parameters directly to the PAR endpoint (`/connect/par`) via HTTP POST
2. IdentityServer validates the parameters and returns a `request_uri`
3. The client redirects the browser to the authorize endpoint with just the `request_uri`
4. IdentityServer looks up the stored parameters and proceeds with the flow

This prevents authorization parameters (scopes, claims, redirect URIs) from being visible in browser URLs or history.
