# Custom `employee_info` Identity Resource

Here's the full configuration: the custom identity resource, an interactive client that can request it, and the registration. `openid` is kept because OIDC requires it.

```csharp
using Duende.IdentityServer.Models;

public static class Config
{
    public static IEnumerable<IdentityResource> IdentityResources =>
        new IdentityResource[]
        {
            new IdentityResources.OpenId(),
            new IdentityResources.Profile(),

            new IdentityResource(
                name: "employee_info",
                displayName: "Employee information",
                userClaims: new[] { "employee_id", "department", "hire_date" })
        };

    public static IEnumerable<Client> Clients =>
        new Client[]
        {
            new Client
            {
                ClientId = "employee-portal",
                AllowedGrantTypes = GrantTypes.Code,
                RequirePkce = true,
                ClientSecrets = { new Secret("secret".Sha256()) },

                RedirectUris           = { "https://portal.example.com/signin-oidc" },
                PostLogoutRedirectUris = { "https://portal.example.com/signout-callback-oidc" },

                AllowedScopes =
                {
                    "openid",
                    "profile",
                    "employee_info"
                }
            }
        };
}
```

Registration:

```csharp
builder.Services.AddIdentityServer()
    .AddInMemoryIdentityResources(Config.IdentityResources)
    .AddInMemoryClients(Config.Clients);
```

## Notes

- The `employee_info` identity resource carries the `employee_id`, `department`, and `hire_date` claims into the ID token / userinfo when granted.
- `openid` is kept because it's required by OpenID Connect (returns `sub`).
- The client lists `employee_info` in its `AllowedScopes` so it can request the scope.
- Your profile service / user store must supply the three claim values for them to appear.
