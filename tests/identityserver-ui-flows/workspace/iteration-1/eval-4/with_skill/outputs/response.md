# Logout Flow Implementation

## 1. Configure the Logout URL in Program.cs

```csharp
builder.Services.AddIdentityServer(opt =>
{
    opt.UserInteraction.LogoutUrl = "/Account/Logout";
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
        AllowedScopes = { "openid", "profile", "email", "api1" },
        RequireConsent = true,
        BackChannelLogoutUri = "https://app.example.com/bff/backchannel"
    },
    // ... other clients
});
```

## 2. Logout Page

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

    public string? SignOutIFrameUrl { get; set; }
    public string? PostLogoutRedirectUri { get; set; }

    public async Task<IActionResult> OnGet(string logoutId)
    {
        var context = await _interaction.GetLogoutContextAsync(logoutId);

        // Sign the user out — this triggers back-channel logout notifications
        await HttpContext.SignOutAsync();

        SignOutIFrameUrl = context?.SignOutIFrameUrl;
        PostLogoutRedirectUri = context?.PostLogoutRedirectUri;

        if (!string.IsNullOrEmpty(PostLogoutRedirectUri))
        {
            return Page(); // Show logout page with iframe, then redirect
        }

        return Page();
    }
}
```

## 3. Logout Razor View with Front-Channel Iframe

```html
@page
@model LogoutModel

<h2>You have been signed out</h2>

@if (!string.IsNullOrEmpty(Model.SignOutIFrameUrl))
{
    <iframe src="@Model.SignOutIFrameUrl" width="0" height="0"
            style="display:none; visibility:hidden;"></iframe>
}

@if (!string.IsNullOrEmpty(Model.PostLogoutRedirectUri))
{
    <p>Click <a href="@Model.PostLogoutRedirectUri">here</a> to return to the application.</p>
}
```

## Key Design Points

1. **`opt.UserInteraction.LogoutUrl`**: Set to `/Account/Logout` so IdentityServer knows where to redirect for logout.
2. **`GetLogoutContextAsync(logoutId)`**: Retrieves the logout context containing SignOutIFrameUrl and PostLogoutRedirectUri.
3. **`HttpContext.SignOutAsync()`**: Ends the authentication session. IdentityServer also triggers back-channel logout via `IBackChannelLogoutService`.
4. **`SignOutIFrameUrl`**: Rendered in an iframe for front-channel logout notifications to client applications.
5. **`BackChannelLogoutUri`**: The web.app client has `BackChannelLogoutUri = "https://app.example.com/bff/backchannel"` for back-channel logout.
