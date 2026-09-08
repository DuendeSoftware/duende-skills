# Azure AD external login with claim mapping on IdentityServer

There are two places to shape claims from Azure AD:

1. **The OIDC handler** — declaratively whitelist/rename incoming AAD claims with `ClaimActions`.
2. **The login callback** — where the external cookie is read and the local `IdentityServerUser` is signed in, mapping AAD-specific claims (like `oid` and `groups`) into your internal claim model.

## 1. OIDC handler for Azure AD

```csharp
using Duende.IdentityServer;

builder.Services.AddAuthentication()
    .AddOpenIdConnect("aad", "Azure AD", options =>
    {
        options.Authority = "https://login.microsoftonline.com/{tenantId}/v2.0";
        options.ClientId = "<client-id>";
        options.ClientSecret = "<client-secret>";
        options.ResponseType = "code";

        // External logins on IdentityServer sign in to the external cookie,
        // which the callback then converts into the real session.
        options.SignInScheme = IdentityServerConstants.ExternalCookieAuthenticationScheme;

        // Keep the original short claim names — don't rename to WS-Federation URIs.
        options.MapInboundClaims = false;

        options.Scope.Clear();
        options.Scope.Add("openid");
        options.Scope.Add("profile");
        options.Scope.Add("email");

        // Remove ALL default claim mappings, then whitelist only what you need.
        options.ClaimActions.Clear();
        options.ClaimActions.MapJsonKey(JwtClaimTypes.Subject, "oid");   // AAD object id
        options.ClaimActions.MapJsonKey(JwtClaimTypes.Name, "name");
        options.ClaimActions.MapJsonKey(JwtClaimTypes.Email, "email");
        options.ClaimActions.MapJsonKey("aad_oid", "oid");              // keep oid for correlation
        options.ClaimActions.MapJsonKey("groups", "groups");           // raw AAD groups
        options.ClaimActions.MapJsonKey(JwtClaimTypes.Role, "roles");  // AAD app roles → role
    });
```

Key points:
- `MapInboundClaims = false` stops the handler renaming `sub`/`name`/etc. to long Microsoft URIs.
- `ClaimActions.Clear()` wipes the default mappings so nothing leaks through implicitly; you then `MapJsonKey` only the claims you want.
- `SignInScheme = IdentityServerConstants.ExternalCookieAuthenticationScheme` routes the external identity into the temporary external cookie.

## 2. Login callback — map AAD claims to internal types

The callback reads the external cookie, extracts the provider user id, provisions/looks up the local user, then signs in an `IdentityServerUser` whose `AdditionalClaims` are the normalized AAD claims (mapping `groups` → roles here):

```csharp
public async Task<IActionResult> Callback()
{
    var result = await HttpContext.AuthenticateAsync(
        IdentityServerConstants.ExternalCookieAuthenticationScheme);
    if (result?.Succeeded != true)
    {
        throw new InvalidOperationException("External authentication error");
    }

    var externalUser = result.Principal!;
    var provider = result.Properties.Items["scheme"]!;

    // AAD's stable per-tenant object id
    var providerUserId =
        externalUser.FindFirst("oid")?.Value
        ?? externalUser.FindFirst(JwtClaimTypes.Subject)?.Value
        ?? throw new InvalidOperationException("Unknown userid");

    var user = await _userService.FindByExternalProviderAsync(provider, providerUserId)
        ?? await _userService.ProvisionUserAsync(provider, providerUserId, externalUser.Claims);

    var identityServerUser = new IdentityServerUser(user.SubjectId)
    {
        DisplayName = user.DisplayName,
        IdentityProvider = provider,
        AdditionalClaims = MapAzureAdClaims(externalUser.Claims)
    };

    await HttpContext.SignInAsync(identityServerUser, result.Properties);
    await HttpContext.SignOutAsync(IdentityServerConstants.ExternalCookieAuthenticationScheme);

    var returnUrl = result.Properties.Items["returnUrl"] ?? "~/";
    return Redirect(returnUrl);
}

private static ICollection<Claim> MapAzureAdClaims(IEnumerable<Claim> claims)
{
    var mapped = new List<Claim>();

    // oid → internal aad_oid for correlation
    var oid = claims.FirstOrDefault(c => c.Type == "oid")?.Value;
    if (oid is not null)
    {
        mapped.Add(new Claim("aad_oid", oid));
    }

    // AAD "groups" → application role claims
    foreach (var group in claims.Where(c => c.Type == "groups"))
    {
        if (AadGroupRoleMap.TryGetValue(group.Value, out var role))
        {
            mapped.Add(new Claim(JwtClaimTypes.Role, role));
        }
    }

    return mapped;
}
```

## Summary

- Configure the AAD OIDC handler with `MapInboundClaims = false`, `SignInScheme = IdentityServerConstants.ExternalCookieAuthenticationScheme`, `ClaimActions.Clear()`, then explicit `MapJsonKey` for `oid`, `groups`, etc.
- In the callback, read the external cookie, translate AAD `oid`/`groups` into internal claim types (mapping groups → roles), and sign the user in via `IdentityServerUser`.
