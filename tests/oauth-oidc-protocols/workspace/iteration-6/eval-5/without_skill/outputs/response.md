# Getting user info when the access token is opaque

Access tokens are for the API, not the client. The client should never parse them; the format is an implementation detail that can change (as you've seen). Get identity data from the **ID token** or the **UserInfo endpoint**.

## Options
1. **ID token claims**: with OIDC, request `openid profile email`; the middleware validates the ID token and populates `User`.
2. **UserInfo endpoint**: call `/connect/userinfo` with the access token. Works with reference tokens.

```csharp
.AddOpenIdConnect("oidc", o =>
{
    o.Authority = "https://identity.example.com";
    o.ClientId = "web"; o.ClientSecret = "secret";
    o.ResponseType = "code";
    o.Scope.Add("openid"); o.Scope.Add("profile"); o.Scope.Add("email");
    o.SaveTokens = true;
    o.GetClaimsFromUserInfoEndpoint = true; // merges userinfo claims into User
    o.MapInboundClaims = false;
});
```
Then `User.FindFirst("name")`, `User.FindFirst("email")`.

Manual call:
```csharp
var token = await HttpContext.GetTokenAsync("access_token");
var disco = await client.GetDiscoveryDocumentAsync("https://identity.example.com");
var info = await client.GetUserInfoAsync(new UserInfoRequest { Address = disco.UserInfoEndpoint, Token = token });
var name = info.Claims.First(c => c.Type == "name").Value;
```

Ensure the client's scopes include `openid`, `profile`, `email` (IdentityResources registered on the server). If claims are missing from the ID token, the server may have `AlwaysIncludeUserClaimsInIdToken = false`; the userinfo approach covers that. Pass the access token to your API only as an opaque string; the API validates via introspection.
