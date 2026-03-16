# Home Realm Discovery for IdentityServer Login

Here's how to implement HRD with multiple external providers.

## Login Page with HRD

```csharp
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;

namespace IdentityServer.Pages;

public class LoginModel : PageModel
{
    [BindProperty]
    public string Email { get; set; }

    [BindProperty]
    public string Password { get; set; }

    [BindProperty]
    public string ReturnUrl { get; set; }

    public async Task<IActionResult> OnGet(string returnUrl)
    {
        ReturnUrl = returnUrl;
        return Page();
    }

    public async Task<IActionResult> OnPost()
    {
        // Check email domain for routing
        if (!string.IsNullOrEmpty(Email))
        {
            if (Email.EndsWith("@contoso.com"))
            {
                // Route contoso users to AAD
                var props = new AuthenticationProperties
                {
                    RedirectUri = "/ExternalLoginCallback",
                    Items = { { "returnUrl", ReturnUrl } }
                };
                return Challenge(props, "AAD");
            }
        }

        // Local login for non-contoso users
        // Validate credentials...
        
        return Page();
    }
}
```

## Program.cs — Provider Registration

```csharp
// Register external providers
builder.Services.AddAuthentication()
    .AddOpenIdConnect("AAD", "Corporate Login", options =>
    {
        options.Authority = "https://login.microsoftonline.com/contoso.com/v2.0";
        options.ClientId = "your-client-id";
        options.ResponseType = "code";
    })
    .AddGoogle("Google", options =>
    {
        options.ClientId = "google-client-id";
        options.ClientSecret = "google-secret";
    });
```

### Notes

- Route users based on email domain — @contoso.com goes to AAD.
- Show Google and local login as options for other users.
- Use `Challenge()` to redirect to the appropriate external provider.
- Consider restricting providers per client if needed.
