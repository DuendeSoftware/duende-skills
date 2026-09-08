# Adding Azure AD External Login to IdentityServer

## 1. Register the Azure AD OpenID Connect handler

In `Program.cs`, add an OpenID Connect authentication handler with the scheme `AAD`. Set the `SignInScheme` to IdentityServer's external cookie so the external identity lands in a temporary cookie that the callback can read.

```csharp
using Duende.IdentityServer;

builder.Services.AddAuthentication()
    .AddOpenIdConnect("AAD", "Corporate Login", options =>
    {
        options.SignInScheme = IdentityServerConstants.ExternalCookieAuthenticationScheme;

        options.Authority = "https://login.microsoftonline.com/{tenantId}/v2.0";
        options.ClientId = "{clientId}";
        options.ClientSecret = "{clientSecret}";
        options.ResponseType = "code";
        options.Scope.Add("openid");
        options.Scope.Add("profile");
        options.CallbackPath = "/signin-aad";
    });
```

## 2. Trigger the challenge

When the user picks "Corporate Login", issue a challenge to the `AAD` scheme and stash the `returnUrl` in the authentication properties so it survives the redirect to Azure and back.

```csharp
public IActionResult OnGetExternal(string returnUrl)
{
    var props = new AuthenticationProperties
    {
        RedirectUri = Url.Action("Callback"),
        Items =
        {
            { "returnUrl", returnUrl },
            { "scheme", "AAD" }
        }
    };
    return Challenge(props, "AAD");
}
```

## 3. Callback handler

Read the external cookie, find or create a local user, sign the user into IdentityServer, then delete the external cookie.

```csharp
using Duende.IdentityServer;
using System.Security.Claims;

public async Task<IActionResult> Callback()
{
    // Read the identity established by the external provider
    var result = await HttpContext.AuthenticateAsync(
        IdentityServerConstants.ExternalCookieAuthenticationScheme);

    if (result?.Succeeded != true)
        return BadRequest("External authentication failed");

    var externalUser = result.Principal;
    var providerUserId = externalUser.FindFirst(ClaimTypes.NameIdentifier)?.Value
                         ?? externalUser.FindFirst("sub")?.Value;
    var returnUrl = result.Properties.Items["returnUrl"] ?? "~/";
    var scheme = result.Properties.Items["scheme"];

    // Find or provision a local user record
    var user = FindOrCreateUser(scheme, providerUserId, externalUser);

    // Establish the IdentityServer session, recording which IdP was used
    var isUser = new IdentityServerUser(user.SubjectId)
    {
        DisplayName = user.Name,
        IdentityProvider = scheme  // "AAD"
    };
    await HttpContext.SignInAsync(isUser);

    // Clean up the temporary external cookie
    await HttpContext.SignOutAsync(IdentityServerConstants.ExternalCookieAuthenticationScheme);

    if (Url.IsLocalUrl(returnUrl))
        return Redirect(returnUrl);

    return Redirect("~/");
}
```

## Summary

- Scheme `AAD`, display name `Corporate Login`.
- `SignInScheme` is the IdentityServer external cookie so the callback can read the external identity.
- The `returnUrl` is preserved in `AuthenticationProperties.Items`.
- After sign-in, sign out of the external cookie scheme to remove the temporary cookie.
- The `IdentityProvider` property records the originating provider so single sign-out / auditing works.
