# Azure AD login with claim mapping

## 1. OIDC handler with ClaimActions
```csharp
builder.Services.AddAuthentication()
    .AddOpenIdConnect("aad", "Azure AD", options =>
    {
        options.SignInScheme = IdentityServerConstants.ExternalCookieAuthenticationScheme;
        options.Authority = "https://login.microsoftonline.com/{tenantId}/v2.0";
        options.ClientId = "<aad-client-id>";
        options.ClientSecret = builder.Configuration["Aad:ClientSecret"];
        options.ResponseType = "code";
        options.UsePkce = true;
        options.CallbackPath = "/signin-aad";
        options.Scope.Add("profile");
        options.Scope.Add("email");
        options.MapInboundClaims = false;       // keep short claim names
        options.SaveTokens = true;
        options.TokenValidationParameters.NameClaimType = JwtClaimTypes.Name;

        // Whitelist: remove defaults, map only what you need
        options.ClaimActions.Clear();
        options.ClaimActions.MapJsonKey(JwtClaimTypes.Subject, "sub");
        options.ClaimActions.MapJsonKey("oid", "oid");
        options.ClaimActions.MapJsonKey(JwtClaimTypes.Email, "email");
        options.ClaimActions.MapJsonKey(JwtClaimTypes.Name, "name");
        options.ClaimActions.MapJsonKey("groups", "groups");      // see overage note
        options.ClaimActions.MapJsonKey(JwtClaimTypes.Role, "roles");
    });
```
Note: `ClaimActions.Clear()` also removes the default mapping of `sub`, so re-add it. `groups` is only present if the app registration has the groups optional claim; over ~200 groups AAD returns a group overage (`_claim_names`) instead; resolve via Microsoft Graph if you expect that.

## 2. Login callback mapping
```csharp
public async Task<IActionResult> Callback()
{
    var result = await HttpContext.AuthenticateAsync(IdentityServerConstants.ExternalCookieAuthenticationScheme);
    if (result?.Succeeded != true) throw new InvalidOperationException("External authentication error");

    var externalUser = result.Principal ?? throw new InvalidOperationException("No external principal");

    var userIdClaim = externalUser.FindFirst(JwtClaimTypes.Subject)
        ?? externalUser.FindFirst(ClaimTypes.NameIdentifier)
        ?? throw new InvalidOperationException("Unknown userid");

    var provider = result.Properties!.Items["scheme"]
        ?? throw new InvalidOperationException("No scheme in external result");
    var providerUserId = userIdClaim.Value;

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

    var oid = claims.FirstOrDefault(c => c.Type == "oid")?.Value;
    if (oid is not null) mapped.Add(new Claim("aad_oid", oid));      // internal correlation claim

    foreach (var group in claims.Where(c => c.Type == "groups"))
        if (AadGroupRoleMap.TryGetValue(group.Value, out var role))  // group id -> local role
            mapped.Add(new Claim(JwtClaimTypes.Role, role));

    return mapped;
}
```
Key points:
- The user is signed in with an **internal subject id**; external `oid` is a lookup key, not the `sub`.
- Only whitelisted, explicitly mapped claims end up in the session; large group lists bloat the cookie (431/400), so map groups to a few roles here, and load bulk data dynamically in `IProfileService`.
- Declare `role`, `aad_oid` etc. in `UserClaims` of your resources and emit them from the profile service (`AddRequestedClaims`) so they reach tokens.
