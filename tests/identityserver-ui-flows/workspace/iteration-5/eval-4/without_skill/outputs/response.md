# Logout Flow for IdentityServer

## 1. Configure the logout URL

In `Program.cs`, tell IdentityServer where the logout page lives:

```csharp
builder.Services.AddIdentityServer(options =>
{
    options.UserInteraction.LogoutUrl = "/Account/Logout";
})
```

## 2. Configure back-channel logout on the web.app client

Add a `BackChannelLogoutUri` to the `web.app` client so IdentityServer can notify it server-to-server:

```csharp
new Client
{
    ClientId = "web.app",
    // ... existing settings ...
    PostLogoutRedirectUris = { "https://app.example.com/signout-callback-oidc" },
    BackChannelLogoutUri = "https://app.example.com/bff/backchannel"
}
```

## 3. Logout page

```csharp
using Duende.IdentityServer.Services;
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;

public class LogoutModel : PageModel
{
    private readonly IIdentityServerInteractionService _interaction;

    public LogoutModel(IIdentityServerInteractionService interaction)
    {
        _interaction = interaction;
    }

    public string SignOutIframeUrl { get; set; }
    public string PostLogoutRedirectUri { get; set; }

    public async Task<IActionResult> OnGetAsync(string logoutId)
    {
        // Look up the logout context for this request
        var context = await _interaction.GetLogoutContextAsync(logoutId);

        // Sign the user out of the IdentityServer session cookie.
        // This also triggers back-channel logout notifications to clients.
        await HttpContext.SignOutAsync();

        // For front-channel logout, render this URL in an iframe on the page
        SignOutIframeUrl = context?.SignOutIFrameUrl;
        PostLogoutRedirectUri = context?.PostLogoutRedirectUri;

        return Page();
    }
}
```

```html
@page
@model LogoutModel

<h2>You have been signed out.</h2>

@if (!string.IsNullOrEmpty(Model.PostLogoutRedirectUri))
{
    <a href="@Model.PostLogoutRedirectUri">Back to the application</a>
}

@if (!string.IsNullOrEmpty(Model.SignOutIframeUrl))
{
    <iframe width="0" height="0" src="@Model.SignOutIframeUrl"></iframe>
}
```

## How it works

- `GetLogoutContextAsync(logoutId)` gives you the `SignOutIFrameUrl` (front-channel notifications) and the `PostLogoutRedirectUri` (where to send the user afterward).
- `HttpContext.SignOutAsync()` removes the authentication cookie and, because clients with a `BackChannelLogoutUri` are registered, IdentityServer sends them a logout token.
- The iframe pointing at `SignOutIFrameUrl` notifies front-channel clients that the session ended.
- Back-channel (server-to-server) logout is more reliable across domains than the front-channel iframe, which depends on third-party cookies.
