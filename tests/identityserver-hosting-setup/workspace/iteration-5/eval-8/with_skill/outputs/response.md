# Complete IdentityServer with Identity Resources, an API Scope, and an Interactive Client

This sets up identity resources (`openid`, `profile`), an API scope `weatherapi`, and an interactive web client using the authorization code flow with PKCE.

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
                ClientName = "Interactive Web Client",

                AllowedGrantTypes = GrantTypes.Code, // authorization code + PKCE
                RequirePkce = true,                  // PKCE (on by default for Code)

                ClientSecrets = { new Secret("secret".Sha256()) },

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

// Pipeline ordering is critical
app.UseStaticFiles();
app.UseRouting();
app.UseIdentityServer();   // includes UseAuthentication() internally
app.UseAuthorization();

app.MapDefaultControllerRoute();

app.Run();
```

## Notes

- **`GrantTypes.Code`** selects the authorization code flow. PKCE is required by default for code clients (`RequirePkce = true`), which is the recommended, secure setup for interactive apps.
- **`RedirectUris`** must contain the client's OIDC callback: `https://webapp.example.com/signin-oidc`.
- **`PostLogoutRedirectUris`** must contain: `https://webapp.example.com/signout-callback-oidc`.
- **Identity resources** `openid` and `profile` let the client request the `openid`/`profile` scopes and receive the corresponding user claims in the id_token.
- **Pipeline order**: `UseStaticFiles()` → `UseRouting()` → `UseIdentityServer()` → `UseAuthorization()`. `UseIdentityServer()` comes **after** `UseRouting()` and **before** `UseAuthorization()`, and `UseAuthorization()` must not be omitted (the Duende UI template requires it).
