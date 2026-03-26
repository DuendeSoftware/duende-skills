# Adding Azure AD as an External Provider

## Register the OIDC Provider

```csharp
// Program.cs
builder.Services.AddAuthentication()
    .AddOpenIdConnect("AAD", "Corporate Login", options =>
    {
        options.SignInScheme = "ExternalCookie";  // Use a temporary cookie scheme
        options.Authority = "https://login.microsoftonline.com/{tenant-id}/v2.0";
        options.ClientId = "your-aad-client-id";
        options.ClientSecret = "your-aad-client-secret";
        options.ResponseType = "code";
        options.Scope.Add("openid");
        options.Scope.Add("profile");
    });
```

## Trigger the External Login

```csharp
public IActionResult OnGetExternalLogin(string returnUrl)
{
    var properties = new AuthenticationProperties
    {
        RedirectUri = "/external-callback",
        Items = { { "returnUrl", returnUrl } }
    };

    return Challenge(properties, "AAD");
}
```

## Handle the Callback

```csharp
public async Task<IActionResult> OnGetCallback()
{
    var result = await HttpContext.AuthenticateAsync("ExternalCookie");

    if (!result.Succeeded)
        throw new Exception("External authentication error");

    var claims = result.Principal.Claims.ToList();
    var sub = claims.FirstOrDefault(c => c.Type == "sub")?.Value;
    var returnUrl = result.Properties.Items["returnUrl"] ?? "~/";

    // Find or create user
    var user = FindOrCreateUser(sub, claims);

    // Sign in
    var principal = new ClaimsPrincipal(new ClaimsIdentity(new[]
    {
        new Claim("sub", user.Id),
        new Claim("name", user.Name),
        new Claim("idp", "AAD")
    }, "external"));

    await HttpContext.SignInAsync(principal);
    await HttpContext.SignOutAsync("ExternalCookie");

    return Redirect(returnUrl);
}
```

This sets up Azure AD as an external OIDC provider. The key steps are: register the handler, trigger the Challenge, read the external cookie in the callback, sign in the user, and clean up the temporary cookie.
