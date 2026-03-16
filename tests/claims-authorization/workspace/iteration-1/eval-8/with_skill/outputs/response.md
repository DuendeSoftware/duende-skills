# External Azure AD Login with Claim Mapping

## OIDC Handler Configuration

```csharp
builder.Services.AddAuthentication()
    .AddOpenIdConnect("aad", "Azure AD", options =>
    {
        options.Authority = "https://login.microsoftonline.com/{tenantId}/v2.0";
        options.ClientId = "your-client-id";
        options.ClientSecret = "your-client-secret";
        options.ResponseType = "code";

        // Keep short JWT claim names
        options.MapInboundClaims = false;

        // Sign into the external cookie scheme used by IdentityServer
        options.SignInScheme = IdentityServerConstants.ExternalCookieAuthenticationScheme;

        // Remove all default claim mappings
        options.ClaimActions.Clear();

        // Explicitly map only what you need from the AAD id_token
        options.ClaimActions.MapJsonKey(JwtClaimTypes.Subject, "oid");
        options.ClaimActions.MapJsonKey(JwtClaimTypes.Email, "email");
        options.ClaimActions.MapJsonKey(JwtClaimTypes.Name, "name");
        options.ClaimActions.MapJsonKey("department", "department");

        // Map AAD groups to role claims
        options.ClaimActions.MapJsonKey(JwtClaimTypes.Role, "roles");

        // Request groups claim from AAD
        options.Scope.Add("openid");
        options.Scope.Add("profile");
        options.Scope.Add("email");

        options.GetClaimsFromUserInfoEndpoint = true;
        options.SaveTokens = true;
    });
```

## Login Callback Claim Mapping

In your external login callback, map AAD-specific claims (like `oid` and `groups`) to your internal claim types:

```csharp
// ExternalController.cs — login callback
public async Task<IActionResult> Callback()
{
    var result = await HttpContext.AuthenticateAsync(
        IdentityServerConstants.ExternalCookieAuthenticationScheme);

    if (result?.Succeeded != true)
        throw new InvalidOperationException("External authentication error");

    var externalUser = result.Principal
        ?? throw new InvalidOperationException("No external principal");

    var provider = result.Properties.Items["scheme"]
        ?? throw new InvalidOperationException("No scheme");

    var userIdClaim = externalUser.FindFirst(JwtClaimTypes.Subject)
        ?? externalUser.FindFirst(ClaimTypes.NameIdentifier)
        ?? throw new InvalidOperationException("Unknown userid");

    var providerUserId = userIdClaim.Value;

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

    return Redirect(result.Properties.Items["returnUrl"] ?? "~/");
}

private static ICollection<Claim> MapAzureAdClaims(IEnumerable<Claim> claims)
{
    var mapped = new List<Claim>();

    // Map AAD object ID for correlation
    var oid = claims.FirstOrDefault(c => c.Type == "oid")?.Value;
    if (oid is not null)
    {
        mapped.Add(new Claim("aad_oid", oid));
    }

    // Map AAD group claims to role claims
    foreach (var group in claims.Where(c => c.Type == "groups"))
    {
        // Map known group IDs to application roles
        if (AadGroupRoleMap.TryGetValue(group.Value, out var role))
        {
            mapped.Add(new Claim(JwtClaimTypes.Role, role));
        }
    }

    return mapped;
}

private static readonly Dictionary<string, string> AadGroupRoleMap = new()
{
    ["group-id-1"] = "Admin",
    ["group-id-2"] = "Editor",
};
```

## Key Points

- **`MapInboundClaims = false`** keeps short OIDC claim names so `sub`, `name`, etc. are preserved.
- **`ClaimActions.Clear()`** removes the default claim action mappings before adding your explicit ones — this ensures only the claims you want are captured from the AAD response.
- **`MapJsonKey`** maps claims from the user info JSON or id_token JSON payload.
- **`SignInScheme = IdentityServerConstants.ExternalCookieAuthenticationScheme`** ensures the OIDC handler writes to the external cookie used by IdentityServer's callback flow.
- AAD `groups` claims can be mapped to `role` claims either via `ClaimActions.MapJsonKey` or in the callback.
