Here's how to configure the two clients:

```csharp
var builder = WebApplication.CreateBuilder(args);

builder.Services.AddIdentityServer()
    .AddInMemoryApiScopes(new List<ApiScope>
    {
        new ApiScope("orders.read", "Read Orders"),
        new ApiScope("inventory.write", "Write Inventory")
    })
    .AddInMemoryIdentityResources(new List<IdentityResource>
    {
        new IdentityResources.OpenId(),
        new IdentityResources.Profile(),
        new IdentityResources.Email()
    })
    .AddInMemoryClients(new List<Client>
    {
        // Machine-to-machine client
        new Client
        {
            ClientId = "batch-processor",
            ClientName = "Batch Processor",
            AllowedGrantTypes = GrantTypes.ClientCredentials,
            ClientSecrets = { new Secret("secret".Sha256()) },
            AllowedScopes = { "orders.read", "inventory.write" }
        },

        // Interactive web application
        new Client
        {
            ClientId = "admin-portal",
            ClientName = "Admin Portal",
            AllowedGrantTypes = GrantTypes.Code,
            RequirePkce = true,
            ClientSecrets = { new Secret("secret".Sha256()) },
            RedirectUris = { "https://admin.example.com/signin-oidc" },
            PostLogoutRedirectUris = { "https://admin.example.com/signout-callback-oidc" },
            AllowOfflineAccess = true,
            AllowedScopes =
            {
                "openid",
                "profile",
                "email",
                "orders.read"
            }
        }
    });

var app = builder.Build();

app.UseIdentityServer();
app.UseAuthorization();

app.Run();
```

The `batch-processor` client uses client credentials grant for backend service communication, while the `admin-portal` uses authorization code flow with PKCE for interactive user login. The admin portal has `AllowOfflineAccess = true` to receive refresh tokens.
