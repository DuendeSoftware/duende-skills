# Configuring Pushed Authorization Requests (PAR)

PAR (Pushed Authorization Requests) allows clients to push authorization parameters to the server before redirecting the user, keeping sensitive parameters out of URLs.

## Server Configuration

```csharp
var builder = WebApplication.CreateBuilder(args);

builder.Services.AddIdentityServer(options =>
{
    // Require PAR for all clients
    options.PushedAuthorization.Required = true;
    
    // Set PAR request lifetime to 5 minutes
    options.PushedAuthorization.Lifetime = TimeSpan.FromMinutes(5);
})
    .AddInMemoryClients(new[]
    {
        new Client
        {
            ClientId = "banking_app",
            AllowedGrantTypes = GrantTypes.Code,
            RequirePkce = true,
            ClientSecrets = { new Secret("secret".Sha256()) },
            RedirectUris = { "https://banking.example.com/callback" },
            AllowedScopes = { "openid", "profile", "api1" },
            
            // Per-client PAR settings
            RequirePushedAuthorization = true
        }
    })
    .AddInMemoryApiScopes(Config.ApiScopes)
    .AddInMemoryIdentityResources(Config.IdentityResources);

var app = builder.Build();
app.UseIdentityServer();
app.UseAuthorization();
app.Run();
```

## How PAR Works

1. Client POSTs authorization parameters to the PAR endpoint
2. Server returns a `request_uri`
3. Client redirects browser to authorize endpoint with just the `request_uri`
4. Server retrieves the stored parameters

## Notes

- PAR helps keep authorization parameters private (not in browser URLs)
- The PAR endpoint is typically at `/connect/par`
- Required by some security profiles like FAPI 2.0
- The `request_uri` is a one-time-use reference
