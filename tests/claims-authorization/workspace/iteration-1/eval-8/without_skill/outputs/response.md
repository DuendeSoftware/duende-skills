# Setting Up Azure AD External Login with IdentityServer

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

        options.ClaimActions.MapJsonKey("oid", "oid");
        options.ClaimActions.MapJsonKey("email", "email");
        options.ClaimActions.MapJsonKey("name", "name");

        options.Scope.Add("email");
        options.Scope.Add("profile");
    });
```

Then in your login callback, you can read the external authentication result and map the claims to your local user model.

```csharp
var result = await HttpContext.AuthenticateAsync("aad");
var claims = result.Principal.Claims;

// Map oid claim
var oid = claims.FirstOrDefault(c => c.Type == "oid")?.Value;
// Map groups to roles
var groups = claims.Where(c => c.Type == "groups").Select(c => c.Value);
```

This sets up Azure AD as an external provider and allows you to access the AAD-specific claims for mapping.
