# Configuring Key Rotation in IdentityServer

Here's the updated `Program.cs` with key management configured for your requirements:

```csharp
// Program.cs
using Duende.IdentityServer.Models;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddIdentityServer(options =>
{
    // Rotate keys every 30 days
    options.KeyManagement.RotationInterval = TimeSpan.FromDays(30);

    // Announce new keys 5 days before activation
    options.KeyManagement.PropagationTime = TimeSpan.FromDays(5);

    // Retain old keys for 7 days after rotation
    options.KeyManagement.RetentionDuration = TimeSpan.FromDays(7);

    // Keep retired keys around, don't auto-delete them
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

This configures IdentityServer to automatically manage signing keys with a 30-day rotation cycle. New keys are announced 5 days before they become the active signing key, giving clients time to refresh their key caches. After rotation, old keys are retained for 7 days to validate existing tokens. Retired keys are not deleted, so they remain in storage for reference.
