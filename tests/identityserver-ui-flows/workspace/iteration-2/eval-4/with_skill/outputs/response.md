# Logout Flow Implementation

Here's the complete logout flow with URL configuration, logout context, session termination, front-channel notifications via SignOutIFrameUrl, and back-channel logout configuration.

## Updated Program.cs

```csharp
using Duende.IdentityServer;
using Duende.IdentityServer.Models;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddRazorPages();

builder.Services.AddIdentityServer(options =>
    {
        // Configure the logout URL
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
            AllowedScopes = { "openid", "profile", "email", "api1" },
            RequireConsent = true,

            // Configure back-channel logout for web.app
            BackChannelLogoutUri = "https://app.example.com/bff/backchannel"
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
    })
    .AddTestUsers(new List<Duende.IdentityServer.Test.TestUser>
    {
        new Duende.IdentityServer.Test.TestUser
        {
            SubjectId = "1",
            Username = "alice",
            Password = "password"
        }
    });

var app = builder.Build();

app.UseStaticFiles();
app.UseRouting();
app.UseIdentityServer();
app.UseAuthorization();
app.MapRazorPages();

app.Run();
```

## Pages/Logout.cshtml

```cshtml
@page
@model LogoutModel

@if (Model.ShowLoggedOut)
{
    <h1>You are now logged out</h1>

    @if (!string.IsNullOrEmpty(Model.PostLogoutRedirectUri))
    {
        <p><a href="@Model.PostLogoutRedirectUri">Return to application</a></p>
    }

    @if (!string.IsNullOrEmpty(Model.SignOutIFrameUrl))
    {
        <!-- Front-channel logout: notify clients via iframe -->
        <iframe src="@Model.SignOutIFrameUrl" width="0" height="0" style="display:none;"></iframe>
    }
}
else
{
    <h1>Logout</h1>
    <p>Are you sure you want to log out?</p>
    <form method="post">
        <input type="hidden" asp-for="LogoutId" />
        <button type="submit">Yes, log out</button>
    </form>
}
```

## Pages/Logout.cshtml.cs

```csharp
using Duende.IdentityServer.Services;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;

public class LogoutModel : PageModel
{
    private readonly IIdentityServerInteractionService _interaction;

    public LogoutModel(IIdentityServerInteractionService interaction)
    {
        _interaction = interaction;
    }

    [BindProperty]
    public string LogoutId { get; set; }

    public bool ShowLoggedOut { get; set; }
    public string PostLogoutRedirectUri { get; set; }
    public string SignOutIFrameUrl { get; set; }

    public async Task<IActionResult> OnGet(string logoutId)
    {
        LogoutId = logoutId;

        // Get the logout context to determine if we should show the prompt
        var context = await _interaction.GetLogoutContextAsync(logoutId);

        // If ShowSignoutPrompt is false, we can log out immediately
        if (context?.ShowSignoutPrompt == false)
        {
            return await OnPost();
        }

        return Page();
    }

    public async Task<IActionResult> OnPost()
    {
        // Get the logout context
        var context = await _interaction.GetLogoutContextAsync(LogoutId);

        // Sign the user out — this ends the IdentityServer session
        // Back-channel logout notifications are sent automatically by IdentityServer
        await HttpContext.SignOutAsync();

        ShowLoggedOut = true;

        if (context != null)
        {
            // Render the SignOutIFrameUrl for front-channel logout notifications
            SignOutIFrameUrl = context.SignOutIFrameUrl;

            // Set the post-logout redirect URI
            PostLogoutRedirectUri = context.PostLogoutRedirectUri;
        }

        return Page();
    }
}
```

## Key Points

1. **LogoutUrl configuration**: `opt.UserInteraction.LogoutUrl = "/Logout"` tells IdentityServer where the logout page lives.

2. **GetLogoutContextAsync**: Called with the `logoutId` to retrieve the logout context, which includes `SignOutIFrameUrl` and `PostLogoutRedirectUri`.

3. **HttpContext.SignOutAsync()**: Ends the authentication session. IdentityServer automatically triggers back-channel logout notifications to clients that have `BackChannelLogoutUri` configured.

4. **SignOutIFrameUrl**: Rendered in an `<iframe>` to perform front-channel logout notifications to connected clients.

5. **BackChannelLogoutUri**: The `web.app` client is configured with `BackChannelLogoutUri = "https://app.example.com/bff/backchannel"` for server-to-server logout notifications.
