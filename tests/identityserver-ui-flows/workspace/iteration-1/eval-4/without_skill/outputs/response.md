# Logout Flow for IdentityServer

Here's how to implement the logout flow.

## Program.cs changes

Add the logout URL configuration and back-channel logout URI to the client:

```csharp
builder.Services.AddIdentityServer(options =>
{
    options.UserInteraction.LogoutUrl = "/Account/Logout";
})
.AddInMemoryClients(new List<Client>
{
    new Client
    {
        ClientId = "web.app",
        ClientName = "Web Application",
        AllowedGrantTypes = GrantTypes.Code,
        // ... other settings ...
        PostLogoutRedirectUris = { "https://app.example.com/signout-callback-oidc" },
        // No BackChannelLogoutUri configured here
    }
});
```

## Logout Page

```csharp
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;

namespace IdentityServer.Pages;

public class LogoutModel : PageModel
{
    public async Task<IActionResult> OnGet(string logoutId)
    {
        // Sign the user out
        await HttpContext.SignOutAsync();

        // Redirect to post-logout URI or home
        return Redirect("~/");
    }
}
```

## Logout View

```html
@page
@model IdentityServer.Pages.LogoutModel

<h1>Logged Out</h1>
<p>You have been successfully signed out.</p>
```

### Notes

- Configure `UserInteraction.LogoutUrl` to point to your logout page.
- Call `HttpContext.SignOutAsync()` to end the session.
- If using front-channel logout, render the sign-out iframe on the logged-out page.
- For back-channel logout, configure the `BackChannelLogoutUri` on each client that needs notification.
