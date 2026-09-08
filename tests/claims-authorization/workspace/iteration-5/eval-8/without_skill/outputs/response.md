# Azure AD external login and mapping AAD claims

To add Azure AD as an external provider on IdentityServer, register an OpenID Connect handler pointed at your AAD tenant and sign in to IdentityServer's external cookie scheme. You then map the AAD-specific claims (`oid`, `groups`) either declaratively with `ClaimActions` on the handler, or in your login callback.

## OIDC handler configuration

```csharp
using Duende.IdentityServer;

builder.Services.AddAuthentication()
    .AddOpenIdConnect("aad", "Azure AD", options =>
    {
        options.Authority = "https://login.microsoftonline.com/{tenantId}/v2.0";
        options.ClientId = "<client-id>";
        options.ClientSecret = "<client-secret>";
        options.ResponseType = "code";

        // Sign external logins into IdentityServer's external cookie
        options.SignInScheme = IdentityServerConstants.ExternalCookieAuthenticationScheme;

        // Preserve the original claim names instead of the long Microsoft URIs
        options.MapInboundClaims = false;

        options.Scope.Add("openid");
        options.Scope.Add("profile");
        options.Scope.Add("email");

        // Map AAD JSON claims to the claim types you want on the principal
        options.ClaimActions.MapJsonKey("oid", "oid");
        options.ClaimActions.MapJsonKey("groups", "groups");
        options.ClaimActions.MapJsonKey(ClaimTypes.Role, "roles");
    });
```

## Callback claim mapping

In the external login callback, read the external principal, look up or create the local user, and translate the AAD claims into your internal claim types before signing in:

```csharp
public async Task<IActionResult> Callback()
{
    var result = await HttpContext.AuthenticateAsync(
        IdentityServerConstants.ExternalCookieAuthenticationScheme);
    if (result?.Succeeded != true)
    {
        return BadRequest();
    }

    var externalUser = result.Principal!;

    // AAD object id uniquely identifies the user in the tenant
    var oid = externalUser.FindFirst("oid")?.Value
              ?? externalUser.FindFirst(ClaimTypes.NameIdentifier)?.Value;

    var claims = new List<Claim>();
    if (oid is not null)
    {
        claims.Add(new Claim("aad_oid", oid));
    }

    // Map AAD group ids to internal role claims
    foreach (var group in externalUser.FindAll("groups"))
    {
        if (GroupToRoleMap.TryGetValue(group.Value, out var role))
        {
            claims.Add(new Claim(ClaimTypes.Role, role));
        }
    }

    var user = await _users.FindOrCreateAsync("aad", oid!, externalUser.Claims);

    var isUser = new IdentityServerUser(user.SubjectId)
    {
        DisplayName = user.DisplayName,
        IdentityProvider = "aad",
        AdditionalClaims = claims
    };

    await HttpContext.SignInAsync(isUser);
    await HttpContext.SignOutAsync(IdentityServerConstants.ExternalCookieAuthenticationScheme);

    return Redirect(result.Properties!.Items["returnUrl"] ?? "~/");
}
```

## Notes

- `MapInboundClaims = false` keeps the short OIDC claim names.
- `SignInScheme = IdentityServerConstants.ExternalCookieAuthenticationScheme` ensures the external login lands in IdentityServer's dedicated external cookie, which the callback then converts into the real session.
- Mapping `groups` to `role` claims lets you drive `[Authorize(Roles = ...)]` from AAD group membership. Remember to configure your AAD app registration to emit the `groups` (or `roles`) claim.
