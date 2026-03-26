# Configuring Key Rotation in IdentityServer

To configure automatic key management with your specified rotation parameters, you'll need to modify the `AddIdentityServer()` call to include key management options.

## Updated Program.cs

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

## What these settings do

- **RotationInterval**: Keys will rotate every 30 days
- **PropagationTime**: New keys are published 5 days before becoming active, giving clients time to pick them up
- **RetentionDuration**: Old keys are kept in the JWKS for 7 days after rotation
- **DeleteRetiredKeys**: When set to false, keys won't be deleted from storage after the retention period

This configuration ensures smooth key transitions. The propagation time gives clients time to learn about new keys before they start being used for signing, and the retention period ensures tokens signed with old keys can still be validated.
