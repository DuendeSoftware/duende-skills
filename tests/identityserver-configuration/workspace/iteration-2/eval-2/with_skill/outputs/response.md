Here's the updated `Program.cs` with both client definitions added:

```csharp
using Duende.IdentityServer;
using Duende.IdentityServer.Models;

var builder = WebApplication.CreateBuilder(args);

var idsvrBuilder = builder.Services.AddIdentityServer(options =>
{
    options.Events.RaiseErrorEvents = true;
    options.Events.RaiseInformationEvents = true;
    options.Events.RaiseFailureEvents = true;
    options.Events.RaiseSuccessEvents = true;
})
    .AddInMemoryIdentityResources(new List<IdentityResource>
    {
        new IdentityResources.OpenId(),
        new IdentityResources.Profile(),
        new IdentityResources.Email()
    })
    .AddInMemoryApiScopes(new List<ApiScope>
    {
        new ApiScope("orders.read", "Read orders"),
        new ApiScope("inventory.write", "Write inventory")
    })
    .AddInMemoryClients(new List<Client>
    {
        // Machine-to-machine client
        new Client
        {
            ClientId = "batch-processor",
            ClientName = "Batch Processor Service",

            AllowedGrantTypes = GrantTypes.ClientCredentials,
            ClientSecrets = { new Secret("secret".Sha256()) },

            AllowedScopes = { "orders.read", "inventory.write" }
        },

        // Interactive web application client
        new Client
        {
            ClientId = "admin-portal",
            ClientName = "Admin Portal",

            AllowedGrantTypes = GrantTypes.Code,
            RequirePkce = true, // Default is true in Duende IdentityServer

            ClientSecrets = { new Secret("secret".Sha256()) },

            RedirectUris = { "https://admin.example.com/signin-oidc" },
            PostLogoutRedirectUris = { "https://admin.example.com/signout-callback-oidc" },

            AllowOfflineAccess = true, // Enable refresh tokens

            AllowedScopes =
            {
                IdentityServerConstants.StandardScopes.OpenId,
                IdentityServerConstants.StandardScopes.Profile,
                IdentityServerConstants.StandardScopes.Email,
                "orders.read"
            }
        }
    });

var app = builder.Build();

app.UseIdentityServer();
app.UseAuthorization();

app.MapGet("/", () => "IdentityServer is running");

app.Run();
```

**Key points:**

1. **`batch-processor`** uses `GrantTypes.ClientCredentials` for M2M communication with no user involved. Its `AllowedScopes` include both `orders.read` and `inventory.write`.

2. **`admin-portal`** uses `GrantTypes.Code` (authorization code flow) with PKCE (`RequirePkce = true`, which is the default in Duende IS). `AllowOfflineAccess = true` enables refresh token issuance. The `AllowedScopes` include `IdentityServerConstants.StandardScopes.OpenId` (required for OIDC), `Profile`, `Email`, and `orders.read`.

3. The `RedirectUris` and `PostLogoutRedirectUris` are set to the exact URLs specified — exact match is required by IdentityServer.
