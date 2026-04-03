# External Azure AD Login with Claim Mapping

Here's how to set up an Azure AD external login on your IdentityServer with proper claim mapping.

## OIDC Handler Configuration

```csharp
builder.Services.AddAuthentication()
    .AddOpenIdConnect("aad", "Azure AD", options =>
    {
        options.Authority = "https://login.microsoftonline.com/{tenantId}/v2.0";
        options.ClientId = "your-client-id";
        options.ClientSecret = "your-client-secret";
        options.ResponseType = "code";

        // Prevent the handler from renaming claims
        options.MapInboundClaims = false;

        // Sign in to the external cookie scheme — IdentityServer handles the rest
        options.SignInScheme = IdentityServerConstants.ExternalCookieAuthenticationScheme;

        // Remove ALL default claim actions
        options.ClaimActions.Clear();

        // Explicitly map only the claims you need
        options.ClaimActions.MapJsonKey(JwtClaimTypes.Subject, "oid");
        options.ClaimActions.MapJsonKey(JwtClaimTypes.Email, "email");
        options.ClaimActions.MapJsonKey(JwtClaimTypes.Name, "name");
        options.ClaimActions.MapJsonKey("department", "department");

        // Map AAD group/role claims
        options.ClaimActions.MapJsonKey(JwtClaimTypes.Role, "roles");

        options.Scope.Clear();
        options.Scope.Add("openid");
        options.Scope.Add("profile");
        options.Scope.Add("email");
    });
```

## Login Callback Claim Mapping

In your external login callback (e.g. `ExternalController.Callback`):

```csharp
public async Task<IActionResult> Callback()
{
    var result = await HttpContext.AuthenticateAsync(
        IdentityServerConstants.ExternalCookieAuthenticationScheme);

    if (result?.Succeeded != true)
        throw new InvalidOperationException("External authentication error");

    var externalUser = result.Principal!;

    var userIdClaim = externalUser.FindFirst(JwtClaimTypes.Subject)
        ?? externalUser.FindFirst(ClaimTypes.NameIdentifier)
        ?? throw new InvalidOperationException("Unknown userid");

    var provider = result.Properties!.Items["scheme"]!;
    var providerUserId = userIdClaim.Value;

    // Find or provision the local user
    var user = await _userService.FindByExternalProviderAsync(provider, providerUserId)
        ?? await _userService.ProvisionUserAsync(provider, providerUserId, externalUser.Claims);

    // Map AAD-specific claims to internal types
    var additionalClaims = MapAzureAdClaims(externalUser.Claims);

    var identityServerUser = new IdentityServerUser(user.SubjectId)
    {
        DisplayName = user.DisplayName,
        IdentityProvider = provider,
        AdditionalClaims = additionalClaims
    };

    await HttpContext.SignInAsync(identityServerUser, result.Properties);
    await HttpContext.SignOutAsync(IdentityServerConstants.ExternalCookieAuthenticationScheme);

    var returnUrl = result.Properties.Items["returnUrl"] ?? "~/";
    return Redirect(returnUrl);
}

private static ICollection<Claim> MapAzureAdClaims(IEnumerable<Claim> claims)
{
    var mapped = new List<Claim>();

    // Map AAD object ID for correlation
    var oid = claims.FirstOrDefault(c => c.Type == "oid")?.Value;
    if (oid is not null)
        mapped.Add(new Claim("aad_oid", oid));

    // Map AAD groups to role claims
    foreach (var groupClaim in claims.Where(c => c.Type == "groups"))
    {
        // Map group IDs to role names based on your mapping
        if (AadGroupRoleMap.TryGetValue(groupClaim.Value, out var role))
            mapped.Add(new Claim(JwtClaimTypes.Role, role));
    }

    return mapped;
}
```

## Key Points

- **`MapInboundClaims = false`** prevents the OIDC handler from renaming short JWT claim names to long Microsoft URIs
- **`ClaimActions.Clear()`** removes all default claim actions — then you explicitly add only what you need with `MapJsonKey`
- **`SignInScheme = IdentityServerConstants.ExternalCookieAuthenticationScheme`** ensures the external authentication result goes into the IdentityServer external cookie for callback processing
- The callback reads the external cookie, maps provider-specific claims to your internal model, and signs in with the internal subject
