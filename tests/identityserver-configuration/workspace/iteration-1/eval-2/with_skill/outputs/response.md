# M2M and Interactive Client Configuration

Here are the two client definitions with the corresponding scope and resource registrations:

```csharp
var idsvrBuilder = builder.Services.AddIdentityServer(options =>
{
    options.Events.RaiseErrorEvents = true;
    options.Events.RaiseInformationEvents = true;
    options.Events.RaiseFailureEvents = true;
    options.Events.RaiseSuccessEvents = true;
})
    .AddInMemoryIdentityResources(new IdentityResource[]
    {
        new IdentityResources.OpenId(),
        new IdentityResources.Profile(),
        new IdentityResources.Email()
    })
    .AddInMemoryApiScopes(new ApiScope[]
    {
        new ApiScope("orders.read", "Read orders"),
        new ApiScope("inventory.write", "Write inventory")
    })
    .AddInMemoryClients(new Client[]
    {
        // Machine-to-machine client
        new Client
        {
            ClientId = "batch-processor",
            ClientName = "Batch Processor Service",

            AllowedGrantTypes = GrantTypes.ClientCredentials,
            ClientSecrets = { new Secret("batch-secret".Sha256()) },

            AllowedScopes = { "orders.read", "inventory.write" }
        },

        // Interactive web application
        new Client
        {
            ClientId = "admin-portal",
            ClientName = "Admin Portal",

            AllowedGrantTypes = GrantTypes.Code,
            RequirePkce = true, // Default in Duende, explicit for clarity

            ClientSecrets = { new Secret("admin-secret".Sha256()) },

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
```

## Client Details

### batch-processor (M2M)

- **Grant type**: `ClientCredentials` — no interactive user, service-to-service only.
- **Scopes**: `orders.read` and `inventory.write` — the exact permissions the batch processor needs.
- **Secret**: Hashed with `.Sha256()` — in production, load from configuration or a vault.

### admin-portal (Interactive)

- **Grant type**: `Code` (Authorization Code) — the only recommended flow for interactive clients.
- **PKCE**: Required by default in Duende IdentityServer (`RequirePkce = true`).
- **Refresh tokens**: Enabled via `AllowOfflineAccess = true`.
- **Scopes**: Includes `openid` (required by OIDC spec), `profile`, `email`, and the `orders.read` API scope.
- **Redirect URIs**: Must exactly match what the client sends — no trailing slashes, no wildcards.
