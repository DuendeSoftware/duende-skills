# Fixing OIDC State Length and ReturnUrl Issues

Here's how to address URL length problems with external OIDC providers and ensure the return URL is preserved.

## Updated Program.cs

```csharp
using Duende.IdentityServer;
using Duende.IdentityServer.Models;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddRazorPages();

// Add distributed cache for state storage
builder.Services.AddDistributedMemoryCache();

builder.Services.AddIdentityServer(options =>
    {
        // TODO: Configure user interaction options
    })
    .AddInMemoryClients(new List<Client>
    {
        // ... existing clients ...
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

builder.Services.AddAuthentication()
    .AddOpenIdConnect("corporate-idp", "Corporate IdP", options =>
    {
        options.SignInScheme = IdentityServerConstants.ExternalCookieAuthenticationScheme;
        options.Authority = "https://corporate-idp.example.com";
        options.ClientId = "your-client-id";
        options.ClientSecret = "your-client-secret";
        options.ResponseType = "code";

        // Try to reduce state size by limiting saved tokens
        options.SaveTokens = false;
    });

var app = builder.Build();

app.UseStaticFiles();
app.UseRouting();
app.UseIdentityServer();
app.UseAuthorization();
app.MapRazorPages();

app.Run();
```

## Pages/ExternalLogin.cshtml.cs — Trigger with returnUrl

```csharp
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;

public class ExternalLoginModel : PageModel
{
    public IActionResult OnGet(string returnUrl)
    {
        var props = new AuthenticationProperties
        {
            RedirectUri = Url.Page("/ExternalLoginCallback"),
            Items =
            {
                { "returnUrl", returnUrl }
            }
        };

        return Challenge(props, "corporate-idp");
    }
}
```

## Pages/ExternalLoginCallback.cshtml.cs — Retrieve returnUrl

```csharp
using Duende.IdentityServer;
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using System.Security.Claims;

public class ExternalLoginCallbackModel : PageModel
{
    public async Task<IActionResult> OnGet()
    {
        var result = await HttpContext.AuthenticateAsync(
            IdentityServerConstants.ExternalCookieAuthenticationScheme);

        if (result?.Succeeded != true)
        {
            throw new Exception("External authentication failed");
        }

        var returnUrl = result.Properties.Items["returnUrl"] ?? "~/";
        var userId = result.Principal.FindFirst(ClaimTypes.NameIdentifier)?.Value;

        // Create session
        var claims = new List<Claim>
        {
            new Claim("sub", userId),
            new Claim("idp", "corporate-idp")
        };
        var identity = new ClaimsIdentity(claims, "external");
        await HttpContext.SignInAsync(new ClaimsPrincipal(identity));

        // Clean up external cookie
        await HttpContext.SignOutAsync(IdentityServerConstants.ExternalCookieAuthenticationScheme);

        return Redirect(returnUrl);
    }
}
```

## Notes

- The returnUrl is stored in `AuthenticationProperties.Items` before the Challenge so it survives the redirect
- The callback retrieves it from `result.Properties.Items` after authenticating the external cookie
- For the URL length issue, we've tried reducing token storage, but the fundamental issue with OIDC state size may need a custom state data format or a server-side cache approach
- The distributed memory cache is added but a custom `ISecureDataFormat` implementation would be needed to truly store state server-side
