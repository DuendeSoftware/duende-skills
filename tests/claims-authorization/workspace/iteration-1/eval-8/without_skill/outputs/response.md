# Azure AD External Login Configuration

## OIDC Handler Setup

```csharp
builder.Services.AddAuthentication()
    .AddOpenIdConnect("aad", "Azure AD", options =>
    {
        options.Authority = "https://login.microsoftonline.com/{tenantId}/v2.0";
        options.ClientId = "your-client-id";
        options.ClientSecret = "your-client-secret";
        options.ResponseType = "code";
        options.MapInboundClaims = false;

        options.Scope.Add("openid");
        options.Scope.Add("profile");
        options.Scope.Add("email");

        // Map claims from AAD
        options.ClaimActions.MapJsonKey("oid", "oid");
        options.ClaimActions.MapJsonKey("groups", "groups");

        options.SaveTokens = true;
        options.GetClaimsFromUserInfoEndpoint = true;
    });
```

## Callback Claim Mapping

In your external login callback, you can map AAD claims to your internal types:

```csharp
public async Task<IActionResult> Callback()
{
    var result = await HttpContext.AuthenticateAsync("aad");
    if (!result.Succeeded) return BadRequest();

    var claims = result.Principal.Claims;
    var oid = claims.FirstOrDefault(c => c.Type == "oid")?.Value;
    var groups = claims.Where(c => c.Type == "groups").Select(c => c.Value);

    // Map groups to roles
    var roleClaims = groups.Select(g => new Claim("role", MapGroupToRole(g)));

    // Create user and sign in...
}
```

This will let your IdentityServer process Azure AD claims and map them to your internal claim types.
