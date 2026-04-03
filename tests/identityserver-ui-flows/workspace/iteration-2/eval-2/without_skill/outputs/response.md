# Adding Azure AD as External Identity Provider

Here's how to integrate Azure AD as an external provider in IdentityServer with scheme name 'AAD'.

## Updated Program.cs

```csharp
using Duende.IdentityServer;
using Duende.IdentityServer.Models;
using Microsoft.AspNetCore.Authentication.OpenIdConnect;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddRazorPages();

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

// Register Azure AD
builder.Services.AddAuthentication()
    .AddOpenIdConnect("AAD", "Corporate Login", options =>
    {
        options.Authority = "https://login.microsoftonline.com/{tenant-id}/v2.0";
        options.ClientId = "your-aad-client-id";
        options.ClientSecret = "your-aad-client-secret";
        options.ResponseType = "code";
        options.CallbackPath = "/signin-aad";
    });

var app = builder.Build();

app.UseStaticFiles();
app.UseRouting();
app.UseIdentityServer();
app.UseAuthorization();
app.MapRazorPages();

app.Run();
```

## Pages/ExternalLogin.cshtml.cs — Trigger Challenge

```csharp
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;

public class ExternalLoginModel : PageModel
{
    public IActionResult OnGet(string provider, string returnUrl)
    {
        var props = new AuthenticationProperties
        {
            RedirectUri = Url.Page("/ExternalLoginCallback"),
            Items =
            {
                { "returnUrl", returnUrl }
            }
        };

        return Challenge(props, "AAD");
    }
}
```

## Pages/ExternalLoginCallback.cshtml.cs — Handle Callback

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
        // Read external identity from the default external cookie
        var result = await HttpContext.AuthenticateAsync("Cookies.External");

        if (result?.Succeeded != true)
        {
            throw new Exception("External authentication error");
        }

        var externalUser = result.Principal;
        var userId = externalUser.FindFirst(ClaimTypes.NameIdentifier)?.Value;
        var returnUrl = result.Properties.Items["returnUrl"] ?? "~/";

        // Create local claims identity and sign in
        var claims = new List<Claim>
        {
            new Claim("sub", userId),
            new Claim("name", externalUser.FindFirst(ClaimTypes.Name)?.Value ?? "User"),
            new Claim("idp", "AAD")
        };
        var identity = new ClaimsIdentity(claims, "external");
        var principal = new ClaimsPrincipal(identity);

        await HttpContext.SignInAsync(principal);

        // Delete external cookie
        await HttpContext.SignOutAsync("Cookies.External");

        return Redirect(returnUrl);
    }
}
```

## Notes

- Azure AD is registered using `AddOpenIdConnect` with scheme name "AAD" and display name "Corporate Login"
- The challenge is triggered with authentication properties that store the return URL
- After callback, the external identity is read, a local user session is created, and the external cookie is cleaned up
