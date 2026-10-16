```csharp
using Duende.IdentityServer;
using Duende.IdentityServer.Models;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddIdentityServer()
    .AddInMemoryIdentityResources(new IdentityResource[]
    {
        new IdentityResources.OpenId(),
        new IdentityResources.Profile(),
        new IdentityResource(
            name: "employee_info",
            displayName: "Your employee information",
            userClaims: new[] { "employee_id", "department", "hire_date" })
    })
    .AddInMemoryClients(new[]
    {
        new Client
        {
            ClientId = "hr.portal",
            ClientName = "HR Portal",
            AllowedGrantTypes = GrantTypes.Code,
            RequirePkce = true,
            ClientSecrets = { new Secret(builder.Configuration["Clients:HrPortal:SecretHash"]!) },
            RedirectUris = { "https://hr.example.com/signin-oidc" },
            PostLogoutRedirectUris = { "https://hr.example.com/signout-callback-oidc" },
            AllowedScopes =
            {
                IdentityServerConstants.StandardScopes.OpenId,
                IdentityServerConstants.StandardScopes.Profile,
                "employee_info"
            }
        }
    });

var app = builder.Build();
app.UseIdentityServer();
app.UseAuthorization();
app.Run();
```
- The client requests it with `scope=openid profile employee_info`.
- `openid` must be included (it returns `sub`).
- The identity resource only declares *which* claims are allowed; your `IProfileService`/user store must supply `employee_id`, `department`, `hire_date`.
- The claims appear in the userinfo endpoint (and in the ID token if `AlwaysIncludeUserClaimsInIdToken = true`).
- Optionally set `Required = true` on the resource to hide it as optional on the consent screen.
- The redirect URI/secret placeholders are examples; the secret hash comes from configuration.
