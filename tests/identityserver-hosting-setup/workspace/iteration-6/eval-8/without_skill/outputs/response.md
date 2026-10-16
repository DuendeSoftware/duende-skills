# Complete IdentityServer project

**Config.cs**
```csharp
using Duende.IdentityServer.Models;

public static class Config
{
    public static IEnumerable<IdentityResource> IdentityResources => new IdentityResource[]
    {
        new IdentityResources.OpenId(),
        new IdentityResources.Profile()
    };

    public static IEnumerable<ApiScope> ApiScopes => new[] { new ApiScope("weatherapi") };

    public static IEnumerable<Client> Clients => new[]
    {
        new Client
        {
            ClientId = "webapp",
            ClientSecrets = { new Secret("secret".Sha256()) },
            AllowedGrantTypes = GrantTypes.Code,
            RequirePkce = true,
            RedirectUris = { "https://webapp.example.com/signin-oidc" },
            PostLogoutRedirectUris = { "https://webapp.example.com/signout-callback-oidc" },
            AllowedScopes = { "openid", "profile", "weatherapi" }
        }
    };
}
```

**Program.cs**
```csharp
var builder = WebApplication.CreateBuilder(args);

builder.Services.AddIdentityServer()
    .AddInMemoryIdentityResources(Config.IdentityResources)
    .AddInMemoryApiScopes(Config.ApiScopes)
    .AddInMemoryClients(Config.Clients)
    .AddTestUsers(TestUsers.Users);

var app = builder.Build();

app.UseStaticFiles();
app.UseRouting();
app.UseIdentityServer();
app.UseAuthorization();

app.MapGet("/", () => "Hello World!");
app.Run();
```

You'll need a login UI (e.g. the Duende quickstart UI templates) for interactive sign-in, and a license key for production. The client's `signin-oidc` and `signout-callback-oidc` URIs are the defaults of the ASP.NET Core OIDC handler.
