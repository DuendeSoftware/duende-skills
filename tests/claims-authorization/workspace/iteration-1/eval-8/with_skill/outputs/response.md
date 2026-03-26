# External Azure AD Login with Claim Mapping

Setting up Azure AD as an external identity provider requires configuring the OIDC handler with proper claim mapping and integrating it with IdentityServer's external authentication flow.

## OIDC Handler Configuration

```csharp
builder.Services.AddAuthentication()
    .AddOpenIdConnect("aad", "Azure AD", options =>
    {
        options.Authority = "https://login.microsoftonline.com/{tenantId}/v2.0";
        options.ClientId = builder.Configuration["AzureAd:ClientId"];
        options.ClientSecret = builder.Configuration["AzureAd:ClientSecret"];
        options.ResponseType = "code";
        
        // Keep standard OIDC short claim names
        options.MapInboundClaims = false;
        
        // Sign into IdentityServer's external cookie scheme
        options.SignInScheme = IdentityServerConstants.ExternalCookieAuthenticationScheme;
        
        // Remove all default claim actions — start with a clean slate
        options.ClaimActions.Clear();
        
        // Explicitly map only the claims you need from the AAD token
        options.ClaimActions.MapJsonKey(JwtClaimTypes.Subject, "oid");
        options.ClaimActions.MapJsonKey(JwtClaimTypes.Email, "email");
        options.ClaimActions.MapJsonKey(JwtClaimTypes.Name, "name");
        options.ClaimActions.MapJsonKey("department", "department");
        
        // Map AAD 'roles' claim (from app role assignments) to role claims
        options.ClaimActions.MapJsonKey(JwtClaimTypes.Role, "roles");
        
        options.Scope.Add("email");
        options.Scope.Add("profile");
    });
```

## Login Callback with Claim Mapping

In the external login callback controller, map AAD-specific claims to your internal model:

```csharp
public async Task<IActionResult> Callback()
{
    var result = await HttpContext.AuthenticateAsync(
        IdentityServerConstants.ExternalCookieAuthenticationScheme);

    if (result?.Succeeded != true)
        throw new InvalidOperationException("External authentication error");

    var externalUser = result.Principal!;
    
    // Extract the provider's user identifier
    var userIdClaim = externalUser.FindFirst(JwtClaimTypes.Subject)
        ?? externalUser.FindFirst(ClaimTypes.NameIdentifier)
        ?? throw new InvalidOperationException("Unknown userid");

    var provider = "aad";
    var providerUserId = userIdClaim.Value;

    // Find or provision local user
    var user = await _userService.FindByExternalProviderAsync(provider, providerUserId)
        ?? await _userService.ProvisionUserAsync(provider, providerUserId, externalUser.Claims);

    // Map AAD claims to internal claim types
    var additionalClaims = MapAzureAdClaims(externalUser.Claims);

    var identityServerUser = new IdentityServerUser(user.SubjectId)
    {
        DisplayName = user.DisplayName,
        IdentityProvider = provider,
        AdditionalClaims = additionalClaims,
    };

    await HttpContext.SignInAsync(identityServerUser, result.Properties);
    await HttpContext.SignOutAsync(IdentityServerConstants.ExternalCookieAuthenticationScheme);

    return Redirect(result.Properties.Items["returnUrl"] ?? "~/");
}

private static ICollection<Claim> MapAzureAdClaims(IEnumerable<Claim> claims)
{
    var mapped = new List<Claim>();

    // Map AAD 'oid' to internal identifier
    var oid = claims.FirstOrDefault(c => c.Type == "oid")?.Value;
    if (oid is not null)
        mapped.Add(new Claim("aad_oid", oid));

    // Map AAD group claims to role claims
    foreach (var group in claims.Where(c => c.Type == "groups"))
    {
        mapped.Add(new Claim(JwtClaimTypes.Role, group.Value));
    }

    return mapped;
}
```

## Key Points

- **`MapInboundClaims = false`**: Prevents the handler from renaming standard OIDC claims to long WS-Federation URIs.
- **`ClaimActions.Clear()`**: Removes all default claim mappings so you have full control over which claims are extracted from the AAD token.
- **`ClaimActions.MapJsonKey`**: Maps specific JSON properties from the id_token or userinfo response to claim types.
- **`SignInScheme = IdentityServerConstants.ExternalCookieAuthenticationScheme`**: Ensures the external authentication result is stored in IdentityServer's external cookie, not the main session cookie.
- **AAD groups → roles**: In the callback, AAD group object IDs are mapped to role claims for use in authorization.
