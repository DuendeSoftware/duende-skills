# Adding Azure AD as an External Identity Provider

We register an OpenID Connect handler for Azure AD, use the IdentityServer external cookie as the `SignInScheme`, trigger a `Challenge` that carries the `returnUrl`, and implement a callback that reads the external cookie, provisions a local user, establishes the IdentityServer session, and cleans up the temporary external cookie.

## 1. Register the AAD handler (Program.cs)

The critical setting is `SignInScheme = IdentityServerConstants.ExternalCookieAuthenticationScheme`. The external OIDC handler deposits the incoming external identity into that temporary cookie; the callback then reads it back.

```csharp
using Duende.IdentityServer;

builder.Services.AddAuthentication()
    .AddOpenIdConnect("AAD", "Corporate Login", options =>
    {
        // Deposit the external identity into IdentityServer's external cookie
        options.SignInScheme = IdentityServerConstants.ExternalCookieAuthenticationScheme;

        options.Authority = "https://login.microsoftonline.com/<tenant-id>/v2.0";
        options.ClientId = "<client-id>";
        options.ClientSecret = "<client-secret>";
        options.ResponseType = "code";
        options.CallbackPath = "/signin-aad";
        options.Scope.Add("openid");
        options.Scope.Add("profile");
        options.GetClaimsFromUserInfoEndpoint = true;
    });
```

- Scheme name: `"AAD"`
- Display name: `"Corporate Login"`

## 2. Trigger the external login — Challenge('AAD')

Store the `returnUrl` in `AuthenticationProperties.Items` so it survives the round-trip to Azure AD and back.

```csharp
// Pages/Account/ExternalLogin.cshtml.cs (or a controller action)
public IActionResult OnGet(string scheme, string? returnUrl)
{
    var callbackUrl = Url.Page("/Account/ExternalLogin", pageHandler: "Callback");

    var props = new AuthenticationProperties
    {
        RedirectUri = callbackUrl,
        Items =
        {
            { "scheme", scheme },      // "AAD"
            { "returnUrl", returnUrl }
        }
    };

    // Challenge the AAD provider
    return Challenge(props, scheme); // scheme == "AAD"
}
```

## 3. Callback handler — read external cookie, provision, sign in, clean up

```csharp
using Duende.IdentityServer;
using Duende.IdentityServer.Services;

public async Task<IActionResult> OnGetCallback()
{
    // 1. Read the external identity from the IdentityServer external cookie
    var result = await HttpContext.AuthenticateAsync(
        IdentityServerConstants.ExternalCookieAuthenticationScheme);

    if (result?.Succeeded != true)
    {
        throw new InvalidOperationException("External authentication error");
    }

    var externalUser = result.Principal!;
    var scheme = result.Properties.Items["scheme"]!;          // "AAD"
    var returnUrl = result.Properties.Items["returnUrl"] ?? "~/";

    // Extract the external provider's unique id (provider-specific `sub`)
    var externalUserId =
        externalUser.FindFirst("sub")?.Value ??
        externalUser.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier)?.Value
        ?? throw new InvalidOperationException("Unknown userid");

    // 2. Find or provision the LOCAL user (do not reuse AAD sub directly as your sub)
    var user = FindOrProvisionUser(scheme, externalUserId, externalUser);

    // 3. Establish the IdentityServer session, recording the external IdP
    var isUser = new IdentityServerUser(user.SubjectId)
    {
        DisplayName = user.DisplayName,
        IdentityProvider = scheme   // records `idp` = "AAD" on the session
    };
    await HttpContext.SignInAsync(isUser);

    // 4. Delete the temporary external cookie
    await HttpContext.SignOutAsync(
        IdentityServerConstants.ExternalCookieAuthenticationScheme);

    // 5. Validate and return to the protocol endpoint
    if (Url.IsLocalUrl(returnUrl) || await _interaction.IsValidReturnUrl(returnUrl))
    {
        return Redirect(returnUrl);
    }
    return Redirect("~/");
}
```

## Why each piece matters

| Step | Reason |
| ---- | ------ |
| `SignInScheme = ExternalCookieAuthenticationScheme` | The OIDC handler writes the external identity into a short-lived cookie the callback can read. |
| `Items["returnUrl"]` | Preserves the original authorize request across the external round-trip. |
| `AuthenticateAsync(ExternalCookieAuthenticationScheme)` | Reads back the external identity in the callback. |
| `IdentityProvider = scheme` | Records `idp = AAD` so downstream logic/logout knows the external source. |
| `SignOutAsync(ExternalCookieAuthenticationScheme)` | Cleans up the temporary cookie — a common bug if omitted. |

> Note: `SignOutScheme` for the AAD handler is `IdentityServerConstants.SignoutScheme` without ASP.NET Identity (or `IdentityConstants.ApplicationScheme` if using ASP.NET Identity). The external provider's `sub` is provider-specific — map it to a local user rather than using it directly as the IdentityServer `sub`.
