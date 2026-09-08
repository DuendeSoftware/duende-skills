# Custom `employee_info` Identity Resource

Define a custom identity resource named `employee_info` carrying the `employee_id`, `department`, and `hire_date` claims, keep `openid` (required by OIDC), and let an interactive client request the new scope.

```csharp
using Duende.IdentityServer;
using Duende.IdentityServer.Models;

public static class Config
{
    public static IEnumerable<IdentityResource> IdentityResources =>
        new IdentityResource[]
        {
            new IdentityResources.OpenId(),   // required by the OIDC spec (sub claim)
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
                ClientName = "Employee Portal",

                AllowedGrantTypes = GrantTypes.Code,
                RequirePkce = true,
                ClientSecrets = { new Secret("secret".Sha256()) }, // load from config in prod

                RedirectUris          = { "https://portal.example.com/signin-oidc" },
                PostLogoutRedirectUris = { "https://portal.example.com/signout-callback-oidc" },

                AllowedScopes =
                {
                    IdentityServerConstants.StandardScopes.OpenId,
                    IdentityServerConstants.StandardScopes.Profile,
                    "employee_info"   // custom identity scope
                }
            }
        };
}
```

Register everything:

```csharp
builder.Services.AddIdentityServer()
    .AddInMemoryIdentityResources(Config.IdentityResources)
    .AddInMemoryClients(Config.Clients);
```

## Notes

- **Custom identity resource** — the `employee_info` resource groups the three claim types. When the client requests the `employee_info` scope, those claims are emitted into the identity token / userinfo endpoint (identity resources feed the identity token, not the access token).
- **`openid` stays** — it's mandatory for any OpenID Connect request (returns the `sub` claim), so it remains alongside `profile` and the custom resource.
- **Client access** — the interactive client lists `employee_info` in `AllowedScopes`; a client can only request scopes it's allowed.
- **Emitting the claims** — your `IProfileService` (or the ASP.NET Identity claims pipeline) must actually produce `employee_id`, `department`, and `hire_date` for the signed-in user, otherwise the resource is granted but the claims are empty.
