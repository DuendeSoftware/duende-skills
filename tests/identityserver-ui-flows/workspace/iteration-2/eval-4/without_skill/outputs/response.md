# Logout Flow for IdentityServer

Here's a logout implementation with session termination and client notifications.

## Updated Program.cs

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
            AllowedScopes = { "openid", "profile", "email", "api1" },
            RequireConsent = true,
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

## Pages/Logout.cshtml.cs

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

    [BindProperty]
    public string LogoutId { get; set; }

    public string PostLogoutRedirectUri { get; set; }
    public string IframeUrl { get; set; }

    public async Task<IActionResult> OnGet(string logoutId)
    {
        LogoutId = logoutId;
        return Page();
    }

    public async Task<IActionResult> OnPost()
    {
        var context = await _interaction.GetLogoutContextAsync(LogoutId);

        // Sign the user out
        await HttpContext.SignOutAsync();

        if (context != null)
        {
            PostLogoutRedirectUri = context.PostLogoutRedirectUri;
            IframeUrl = context.SignOutIFrameUrl;
        }

        if (!string.IsNullOrEmpty(PostLogoutRedirectUri))
        {
            return Redirect(PostLogoutRedirectUri);
        }

        return Page();
    }
}
```

## Pages/Logout.cshtml

```cshtml
@page
@model LogoutModel

<h1>Logged Out</h1>

@if (!string.IsNullOrEmpty(Model.IframeUrl))
{
    <iframe src="@Model.IframeUrl" width="0" height="0"></iframe>
}

@if (!string.IsNullOrEmpty(Model.PostLogoutRedirectUri))
{
    <a href="@Model.PostLogoutRedirectUri">Return to application</a>
}
```

## Notes

- The logout URL is configured in IdentityServer options
- The logout page gets the context, signs out the user, and renders client notifications
- The web.app client has a BackChannelLogoutUri configured for back-channel notifications
- Front-channel logout uses the SignOutIFrameUrl in an iframe
