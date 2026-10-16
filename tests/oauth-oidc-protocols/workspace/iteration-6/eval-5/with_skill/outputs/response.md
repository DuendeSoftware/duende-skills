# Getting user info when the access token became a reference token

Your client was relying on something it shouldn't: **access tokens are opaque to clients**. They're meant for the API (the resource server). Their format (JWT vs. reference) is the server's decision, and parsing them in the client breaks when it changes, as you found.

## Correct approach
Clients learn *who the user is* from the **ID token** (always a JWT) and/or the **UserInfo endpoint**.

```csharp
// ❌ breaks with reference tokens
var jwt = new JwtSecurityTokenHandler().ReadJwtToken(accessToken);

// ✅ Use the authenticated principal from the OIDC middleware
var name  = User.FindFirst("name")?.Value;
var email = User.FindFirst("email")?.Value;
```

Configure scopes so those claims are available:
```csharp
.AddOpenIdConnect("oidc", o =>
{
    o.Authority = "https://identity.example.com";
    o.ClientId = "web.app"; o.ClientSecret = "secret";
    o.ResponseType = "code";
    o.Scope.Add("openid"); o.Scope.Add("profile"); o.Scope.Add("email");
    o.SaveTokens = true;
    o.GetClaimsFromUserInfoEndpoint = true; // calls userinfo with the access token and merges claims
    o.MapInboundClaims = false;
});
```
Scopes: `profile` → name, family_name…; `email` → email, email_verified; these go to the ID token and/or userinfo.

Manual userinfo call, endpoint from discovery:
```csharp
var disco = await http.GetDiscoveryDocumentAsync("https://identity.example.com");
var info = await http.GetUserInfoAsync(new UserInfoRequest
{
    Address = disco.UserInfoEndpoint,
    Token = await HttpContext.GetTokenAsync("access_token")
});
var name = info.Claims.First(c => c.Type == "name").Value;
```
Userinfo works with reference tokens because the server resolves them.

Server-side: make sure the client's `AllowedScopes` include `openid`, `profile`, `email` and the IdentityResources are registered. If the claims are not in the ID token, use userinfo (or `AlwaysIncludeUserClaimsInIdToken`), and ensure your `IProfileService` emits them.

Rule of thumb: ID token for authentication, access token only forwarded as `Authorization: Bearer` to the API. The API, not the client, validates it (introspection for reference tokens).
