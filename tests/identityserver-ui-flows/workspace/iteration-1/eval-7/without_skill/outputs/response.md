# Fixing State Parameter Length and ReturnUrl Issues

## The Problem

When using an external OIDC provider, two issues can occur:
1. The state parameter in the URL can become too long
2. The returnUrl can be lost during the external authentication round-trip

## Fix: Store ReturnUrl in AuthenticationProperties

### External Login Trigger

```csharp
public class ExternalLoginModel : PageModel
{
    public IActionResult OnGet(string returnUrl)
    {
        var props = new AuthenticationProperties
        {
            RedirectUri = "/ExternalLoginCallback",
            Items =
            {
                { "returnUrl", returnUrl }
            }
        };

        return Challenge(props, "corporate-idp");
    }
}
```

### External Login Callback

```csharp
public class ExternalLoginCallbackModel : PageModel
{
    public async Task<IActionResult> OnGet()
    {
        var result = await HttpContext.AuthenticateAsync("Cookies");

        if (result?.Succeeded != true)
            throw new Exception("External auth failed");

        var returnUrl = result.Properties?.Items["returnUrl"] ?? "~/";

        // Create local session
        var claims = new List<System.Security.Claims.Claim>
        {
            new("sub", result.Principal.FindFirst("sub")?.Value ?? "unknown"),
            new("name", result.Principal.Identity?.Name ?? "User")
        };
        var identity = new System.Security.Claims.ClaimsIdentity(claims, "external");
        await HttpContext.SignInAsync(new System.Security.Claims.ClaimsPrincipal(identity));

        return Redirect(returnUrl);
    }
}
```

## For the URL Length Issue

Consider reducing the number of scopes requested, or using a distributed cache to store the state server-side. Some OIDC libraries support custom state data formatters that can compress or store state externally.

### Notes

- Always store `returnUrl` in `AuthenticationProperties.Items` before the Challenge.
- Retrieve it from `result.Properties.Items` in the callback.
- Consider using a distributed cache for state storage if URL length is a persistent issue.
