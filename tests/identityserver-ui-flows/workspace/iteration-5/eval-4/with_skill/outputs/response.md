# Logout Flow with Front-Channel and Back-Channel Notifications

The logout flow ends the IdentityServer session, notifies client applications, and returns the user to the client's post-logout URL. We configure the logout URL, use `GetLogoutContextAsync`, render `SignOutIFrameUrl` for front-channel notifications, and add a `BackChannelLogoutUri` to the `web.app` client.

## 1. Configure the logout URL (Program.cs)

The `LogoutUrl` is **not** inferred from the cookie handler — it must be set explicitly.

```csharp
builder.Services.AddIdentityServer(options =>
{
    options.UserInteraction.LogoutUrl = "/Account/Logout";
})
```

## 2. Add BackChannelLogoutUri to the web.app client (Program.cs)

```csharp
new Client
{
    ClientId = "web.app",
    ClientName = "Web Application",
    AllowedGrantTypes = GrantTypes.Code,
    RequirePkce = true,
    ClientSecrets = { new Secret("secret".Sha256()) },
    RedirectUris = { "https://app.example.com/signin-oidc" },
    PostLogoutRedirectUris = { "https://app.example.com/signout-callback-oidc" },
    AllowedScopes = { "openid", "profile", "email", "api1" },
    RequireConsent = true,

    // Back-channel logout: server-to-server logout notification (recommended cross-site)
    BackChannelLogoutUri = "https://app.example.com/bff/backchannel"
}
```

Back-channel logout fires automatically when `HttpContext.SignOutAsync()` is called — IdentityServer's `IBackChannelLogoutService` POSTs a `logout+jwt` to every client that has a `BackChannelLogoutUri`.

## 3. Logout page (Pages/Account/Logout.cshtml.cs)

```csharp
using Duende.IdentityServer.Services;
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;

namespace IdentityServer.Pages.Account;

public class LogoutModel : PageModel
{
    private readonly IIdentityServerInteractionService _interaction;

    public LogoutModel(IIdentityServerInteractionService interaction)
    {
        _interaction = interaction;
    }

    public string? SignOutIFrameUrl { get; set; }
    public string? PostLogoutRedirectUri { get; set; }

    public async Task<IActionResult> OnGet(string? logoutId)
    {
        // Retrieve the logout request context
        var context = await _interaction.GetLogoutContextAsync(logoutId);

        if (User.Identity?.IsAuthenticated == true)
        {
            // End the IdentityServer session (also triggers back-channel logout)
            await HttpContext.SignOutAsync();
        }

        // Front-channel notification: render this URL inside an <iframe>
        SignOutIFrameUrl = context.SignOutIFrameUrl;

        // Where to send the user after logout, if client-initiated
        PostLogoutRedirectUri = context.PostLogoutRedirectUri;

        return Page();
    }
}
```

## 4. Logout page view (Pages/Account/Logout.cshtml)

```html
@page
@model IdentityServer.Pages.Account.LogoutModel

<h1>You are now signed out</h1>

@if (!string.IsNullOrEmpty(Model.PostLogoutRedirectUri))
{
    <p>Return to <a href="@Model.PostLogoutRedirectUri">the application</a>.</p>
}

@* Front-channel logout: notifies clients via hidden iframe *@
@if (!string.IsNullOrEmpty(Model.SignOutIFrameUrl))
{
    <iframe width="0" height="0" class="signout" src="@Model.SignOutIFrameUrl"></iframe>
}
```

## How the notification mechanisms differ

| Mechanism | Trigger | Client setting |
| --------- | ------- | -------------- |
| Front-channel | Render `context.SignOutIFrameUrl` in an `<iframe>` on the logged-out page | `FrontChannelLogoutUri` |
| Back-channel | Automatic on `SignOutAsync()` — server-to-server `logout+jwt` POST | `BackChannelLogoutUri` |

**Recommendation:** For cross-site (BFF) architectures use back-channel logout, since front-channel iframes depend on third-party cookies that browsers increasingly block. The `web.app` client here uses `https://app.example.com/bff/backchannel`, the BFF's built-in back-channel endpoint.
