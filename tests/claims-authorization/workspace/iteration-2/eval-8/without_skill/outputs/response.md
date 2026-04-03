# External Azure AD Login with Claim Mapping

Here's how to set up Azure AD as an external login provider and map its claims.

## OIDC Handler Configuration

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

        // Map specific claims from AAD
        options.ClaimActions.MapJsonKey("oid", "oid");
        options.ClaimActions.MapJsonKey("email", "email");
        options.ClaimActions.MapJsonKey("name", "name");
    });
```

## Processing Claims in the Callback

After the user authenticates with Azure AD, process the callback to map claims:

```csharp
public async Task<IActionResult> ExternalLoginCallback()
{
    var info = await HttpContext.AuthenticateAsync("aad");
    if (!info.Succeeded) return RedirectToAction("Login");

    var claims = info.Principal.Claims;

    // Map AAD claims to your internal model
    var oid = claims.FirstOrDefault(c => c.Type == "oid")?.Value;
    var email = claims.FirstOrDefault(c => c.Type == "email")?.Value;

    // Find or create user, map groups to roles, etc.
    var user = await FindOrCreateUser(oid, email, claims);

    await HttpContext.SignInAsync(user.SubjectId, claims.ToArray());
    return Redirect("~/");
}
```

## Notes

- `MapInboundClaims = false` prevents claim renaming
- Use `ClaimActions.MapJsonKey` to explicitly select which claims to include
- In the callback, map AAD-specific claims like `oid` and `groups` to your internal types
- For group-to-role mapping, maintain a lookup table of AAD group IDs to application roles
