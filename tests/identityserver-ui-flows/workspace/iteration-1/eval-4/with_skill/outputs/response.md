# Logout Flow Implementation

Here's the complete logout flow implementation for IdentityServer.

## Program.cs — Configure Logout URL and Back-Channel Logout

```csharp
using Duende.IdentityServer;
using Duende.IdentityServer.Models;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddRazorPages();

builder.Services.AddIdentityServer(options =>
    {
        options.UserInteraction.LogoutUrl = "/Logout";
    })
    .AddInMemoryClients(new List<Client>
    {
        new Client
        {
            ClientId = "web.app",
            ClientName = "Web Application",
            AllowedGrantTypes = GrantTypes.Code,
            RequirePkce = true,
            ClientSecrets = { new Secret("secret".Sha256()) },
            RedirectUris = { "https://app.example.com/signin-oidc" },
            PostLogoutRedirectUris = { "https://app.example.com/signout-callback-oidc" },
            BackChannelLogoutUri = "https://app.example.com/bff/backchannel",
            AllowedScopes = { "openid", "profile", "email", "api1" },
            RequireConsent = true
        },
        new Client
        {
            ClientId = "spa.app",
            ClientName = "SPA Application",
            AllowedGrantTypes = GrantTypes.Code,
            RequirePkce = true,
            RequireClientSecret = false,
            RedirectUris = { "https://spa.example.com/callback" },
            PostLogoutRedirectUris = { "https://spa.example.com" },
            AllowedScopes = { "openid", "profile", "api1" },
            RequireConsent = false
        }
    })
    .AddInMemoryIdentityResources(new List<IdentityResource>
    {
        new IdentityResources.OpenId(),
        new IdentityResources.Profile(),
        new IdentityResources.Email()
    })
    .AddInMemoryApiScopes(new List<ApiScope>
    {
        new ApiScope("api1", "My API")
    });

var app = builder.Build();

app.UseStaticFiles();
app.UseRouting();
app.UseIdentityServer();
app.UseAuthorization();
app.MapRazorPages();

app.Run();
```

## Pages/Logout.cshtml.cs

```csharp
using Duende.IdentityServer.Services;
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;

namespace IdentityServer.Pages;

public class LogoutModel : PageModel
{
    private readonly IIdentityServerInteractionService _interaction;

    public LogoutModel(IIdentityServerInteractionService interaction)
    {
        _interaction = interaction;
    }

    public string? SignOutIFrameUrl { get; set; }
    public string? PostLogoutRedirectUri { get; set; }

    public async Task<IActionResult> OnGet(string logoutId)
    {
        // Get the logout context using GetLogoutContextAsync
        var context = await _interaction.GetLogoutContextAsync(logoutId);

        // Sign the user out — end the authentication session
        await HttpContext.SignOutAsync();

        // Get front-channel logout iframe URL and post-logout redirect URI
        SignOutIFrameUrl = context?.SignOutIFrameUrl;
        PostLogoutRedirectUri = context?.PostLogoutRedirectUri;

        return Page();
    }
}
```

## Pages/Logout.cshtml

```html
@page
@model IdentityServer.Pages.LogoutModel

<h1>Logged Out</h1>
<p>You have been signed out.</p>

@if (!string.IsNullOrEmpty(Model.SignOutIFrameUrl))
{
    <!-- Front-channel logout: render iframe to notify clients -->
    <iframe src="@Model.SignOutIFrameUrl" width="0" height="0" style="display:none;"></iframe>
}

@if (!string.IsNullOrEmpty(Model.PostLogoutRedirectUri))
{
    <p><a href="@Model.PostLogoutRedirectUri">Return to application</a></p>
}
```

### Key Points

1. **`opt.UserInteraction.LogoutUrl`** is configured to `"/Logout"` in Program.cs.
2. **`GetLogoutContextAsync(logoutId)`** retrieves the logout context including `SignOutIFrameUrl` and `PostLogoutRedirectUri`.
3. **`HttpContext.SignOutAsync()`** ends the authentication session. This also triggers back-channel logout via `IBackChannelLogoutService` to any clients with `BackChannelLogoutUri` configured.
4. **`context.SignOutIFrameUrl`** is rendered in an `<iframe>` for front-channel logout notifications to connected clients.
5. **`BackChannelLogoutUri`** is set to `"https://app.example.com/bff/backchannel"` on the web.app client.
