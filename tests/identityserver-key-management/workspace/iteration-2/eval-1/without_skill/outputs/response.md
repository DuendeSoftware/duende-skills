# Configure Key Rotation for IdentityServer

To set up automatic key rotation with your specified intervals, you'll need to configure the key management options in your IdentityServer setup.

Here's the updated `Program.cs`:

```csharp
using Duende.IdentityServer.Models;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddIdentityServer(options =>
    {
        options.KeyManagement.RotationInterval = TimeSpan.FromDays(30);
        options.KeyManagement.PropagationTime = TimeSpan.FromDays(5);
        options.KeyManagement.RetentionDuration = TimeSpan.FromDays(7);
        options.KeyManagement.DeleteRetiredKeys = false;
    })
    .AddInMemoryClients(new List<Client>
    {
        new Client
        {
            ClientId = "web-app",
            ClientSecrets = { new Secret("secret".Sha256()) },
            AllowedGrantTypes = GrantTypes.Code,
            RedirectUris = { "https://localhost:5002/signin-oidc" },
            AllowedScopes = { "openid", "profile", "api1" }
        },
        new Client
        {
            ClientId = "machine-client",
            ClientSecrets = { new Secret("secret".Sha256()) },
            AllowedGrantTypes = GrantTypes.ClientCredentials,
            AllowedScopes = { "api1" }
        }
    })
    .AddInMemoryApiScopes(new List<ApiScope>
    {
        new ApiScope("api1", "My API")
    })
    .AddInMemoryIdentityResources(new List<IdentityResource>
    {
        new IdentityResources.OpenId(),
        new IdentityResources.Profile()
    });

var app = builder.Build();

app.UseIdentityServer();

app.MapGet("/", () => "IdentityServer is running");

app.Run();
```

This configures:
- Keys rotate every 30 days
- New keys are announced 5 days before becoming active
- Retired keys stay around for 7 days
- Old keys won't be deleted after retirement
