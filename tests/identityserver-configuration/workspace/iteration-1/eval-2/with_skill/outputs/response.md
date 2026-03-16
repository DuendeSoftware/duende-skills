Here are the two client definitions — a machine-to-machine client and an interactive web application client:

```csharp
var builder = WebApplication.CreateBuilder(args);

var idsvrBuilder = builder.Services.AddIdentityServer(options =>
{
    options.Events.RaiseErrorEvents = true;
    options.Events.RaiseInformationEvents = true;
    options.Events.RaiseFailureEvents = true;
    options.Events.RaiseSuccessEvents = true;
})
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
        // Machine-to-machine client using client credentials
        new Client
        {
            ClientId = "batch-processor",
            ClientName = "Batch Processor Service",

            AllowedGrantTypes = GrantTypes.ClientCredentials,
            ClientSecrets = { new Secret("batch-processor-secret".Sha256()) },

            AllowedScopes = { "orders.read", "inventory.write" }
        },

        // Interactive web application using authorization code + PKCE
        new Client
        {
            ClientId = "admin-portal",
            ClientName = "Admin Portal",

            AllowedGrantTypes = GrantTypes.Code,
            RequirePkce = true, // Default is true in Duende IS, but explicit for clarity

            ClientSecrets = { new Secret("admin-portal-secret".Sha256()) },

            RedirectUris = { "https://admin.example.com/signin-oidc" },
            PostLogoutRedirectUris = { "https://admin.example.com/signout-callback-oidc" },

            // Enable refresh tokens
            AllowOfflineAccess = true,

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

Key points:

1. **`batch-processor`** — Uses `GrantTypes.ClientCredentials` for service-to-service communication with no interactive user. It only accesses API scopes (`orders.read`, `inventory.write`).

2. **`admin-portal`** — Uses `GrantTypes.Code` with `RequirePkce = true` (default in Duende IdentityServer). It authenticates users and calls APIs.
   - `AllowOfflineAccess = true` enables refresh token issuance
   - `IdentityServerConstants.StandardScopes.OpenId` is required for any OpenID Connect request
   - Redirect URIs must exactly match what the client application sends — no trailing slashes
