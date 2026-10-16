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
            AllowedGrantTypes = GrantTypes.Code,   // authorization_code
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

builder.Services.AddIdentityServer(options =>
    {
        options.LicenseKey = builder.Configuration["IdentityServer:LicenseKey"];
    })
    .AddInMemoryIdentityResources(Config.IdentityResources)
    .AddInMemoryApiScopes(Config.ApiScopes)
    .AddInMemoryClients(Config.Clients);

var app = builder.Build();

app.UseStaticFiles();
app.UseRouting();
app.UseIdentityServer();   // includes UseAuthentication()
app.UseAuthorization();    // required for the Duende UI
app.MapDefaultControllerRoute();

app.MapGet("/", () => "Hello World!");
app.Run();
```

Notes: add a login UI (e.g. `dotnet new duende-is-ui` or the `duende-is-empty` / `duende-is-aspid` templates) and users (test users or ASP.NET Identity via `AddAspNetIdentity`). In-memory stores suit dev; switch to EF stores for production. Don't commit the license key; and if hosted behind a proxy, enable forwarded headers and configure persistent data protection.
