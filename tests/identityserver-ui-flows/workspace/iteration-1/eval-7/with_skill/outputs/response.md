# Fixing State Storage and ReturnUrl Preservation

## Problem 1: State Parameter Too Long

The OIDC state parameter is stored in the URL by default. For providers that add a lot of data to the state, this can exceed URL length limits. The fix is to use IdentityServer's `AddOidcStateDataFormatterCache` which stores state server-side using `IDistributedCache`.

## Problem 2: ReturnUrl Lost During Round-Trip

The `returnUrl` must be explicitly stored in `AuthenticationProperties.Items` before the Challenge and retrieved from `result.Properties.Items` in the callback.

## Fix in Program.cs

```csharp
// Store OIDC state server-side for the corporate-idp scheme
builder.Services.AddOidcStateDataFormatterCache("corporate-idp");

builder.Services.AddAuthentication()
    .AddOpenIdConnect("corporate-idp", options =>
    {
        options.SignInScheme = IdentityServerConstants.ExternalCookieAuthenticationScheme;
        options.Authority = "https://corporate-idp.example.com";
        options.ClientId = "your-client-id";
        options.ClientSecret = "your-client-secret";
        options.ResponseType = "code";
    });
```

## External Login Trigger (Storing returnUrl)

```csharp
public IActionResult OnGetExternalLogin(string returnUrl)
{
    var callbackUrl = Url.Page("/ExternalLoginCallback");

    var props = new AuthenticationProperties
    {
        RedirectUri = callbackUrl,
        Items =
        {
            { "scheme", "corporate-idp" },
            { "returnUrl", returnUrl }  // Store returnUrl in Items
        }
    };

    return Challenge(props, "corporate-idp");
}
```

## Callback Handler (Retrieving returnUrl)

```csharp
public async Task<IActionResult> OnGetCallback()
{
    // Read the external identity
    var result = await HttpContext.AuthenticateAsync(
        IdentityServerConstants.ExternalCookieAuthenticationScheme);

    if (result?.Succeeded != true)
        throw new Exception("External authentication failed");

    // Retrieve returnUrl from Properties.Items
    var returnUrl = result.Properties.Items["returnUrl"] ?? "~/";
    var scheme = result.Properties.Items["scheme"];

    // Provision user, establish session...
    var isUser = new IdentityServerUser(user.SubjectId)
    {
        IdentityProvider = scheme
    };
    await HttpContext.SignInAsync(isUser);
    await HttpContext.SignOutAsync(IdentityServerConstants.ExternalCookieAuthenticationScheme);

    // Validate returnUrl before redirecting
    if (_interaction.IsValidReturnUrl(returnUrl) || Url.IsLocalUrl(returnUrl))
    {
        return Redirect(returnUrl);
    }

    return Redirect("~/");
}
```

## Key Fixes

1. **`AddOidcStateDataFormatterCache("corporate-idp")`**: Stores the OIDC state server-side using `IDistributedCache`, replacing the URL-based state with a short reference. This solves the URL length issue.
2. **`AuthenticationProperties.Items["returnUrl"]`**: The returnUrl is stored in Items before the Challenge, so it survives the external authentication round-trip.
3. **`result.Properties.Items["returnUrl"]`**: Retrieved in the callback after authenticating against the external cookie scheme.
4. **returnUrl validation**: Checked with `IsValidReturnUrl` or `Url.IsLocalUrl` before redirecting.
