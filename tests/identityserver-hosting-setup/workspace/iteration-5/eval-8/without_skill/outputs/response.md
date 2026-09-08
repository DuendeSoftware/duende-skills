# Full IdentityServer Setup with an Interactive Authorization Code Client

## Config.cs

```csharp
using Duende.IdentityServer;
using Duende.IdentityServer.Models;

public static class Config
{
    public static IEnumerable<IdentityResource> IdentityResources =>
        new IdentityResource[]
        {
            new IdentityResources.OpenId(),
            new IdentityResources.Profile()
        };

    public static IEnumerable<ApiScope> ApiScopes =>
        new[]
        {
            new ApiScope("weatherapi", "Weather API")
        };

    public static IEnumerable<Client> Clients =>
        new[]
        {
            new Client
            {
                ClientId = "webapp",
                ClientSecrets = { new Secret("secret".Sha256()) },

                AllowedGrantTypes = GrantTypes.Code, // authorization code with PKCE

                RedirectUris = { "https://webapp.example.com/signin-oidc" },
                PostLogoutRedirectUris = { "https://webapp.example.com/signout-callback-oidc" },

                AllowedScopes =
                {
                    IdentityServerConstants.StandardScopes.OpenId,
                    IdentityServerConstants.StandardScopes.Profile,
                    "weatherapi"
                }
            }
        };
}
```

## Program.cs

```csharp
var builder = WebApplication.CreateBuilder(args);

builder.Services.AddIdentityServer()
    .AddInMemoryIdentityResources(Config.IdentityResources)
    .AddInMemoryApiScopes(Config.ApiScopes)
    .AddInMemoryClients(Config.Clients);

var app = builder.Build();

app.UseStaticFiles();
app.UseRouting();
app.UseIdentityServer();
app.UseAuthorization();

app.MapDefaultControllerRoute();

app.Run();
```

## Notes

- `GrantTypes.Code` is the authorization code flow; Duende enables PKCE for code clients by default (`RequirePkce` defaults to `true`), which is the recommended flow for interactive web apps.
- The identity resources `OpenId` and `Profile` allow the client to request `openid` and `profile` and receive the standard user claims.
- `RedirectUris` includes `https://webapp.example.com/signin-oidc` and `PostLogoutRedirectUris` includes `https://webapp.example.com/signout-callback-oidc`, matching the standard OIDC callback paths.
- Middleware order: `UseRouting()` → `UseIdentityServer()` → `UseAuthorization()`, so IdentityServer runs after routing and before authorization.
