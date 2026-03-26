# Client Configuration

Here are the client definitions:

```csharp
builder.Services.AddIdentityServer()
    .AddInMemoryApiScopes(new[]
    {
        new ApiScope("orders.read"),
        new ApiScope("inventory.write")
    })
    .AddInMemoryClients(new[]
    {
        new Client
        {
            ClientId = "batch-processor",
            AllowedGrantTypes = GrantTypes.ClientCredentials,
            ClientSecrets = { new Secret("secret".Sha256()) },
            AllowedScopes = { "orders.read", "inventory.write" }
        },
        new Client
        {
            ClientId = "admin-portal",
            AllowedGrantTypes = GrantTypes.Code,
            ClientSecrets = { new Secret("secret".Sha256()) },
            RedirectUris = { "https://admin.example.com/signin-oidc" },
            PostLogoutRedirectUris = { "https://admin.example.com/signout-callback-oidc" },
            AllowedScopes = { "profile", "email", "orders.read" }
        }
    });
```

The batch-processor uses client credentials for server-to-server communication. The admin-portal uses authorization code flow for interactive login.
