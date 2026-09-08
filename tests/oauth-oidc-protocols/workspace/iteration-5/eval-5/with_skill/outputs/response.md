# Getting User Info in a Client — the Right Way

The upgrade didn't break a bug in your code; it exposed an incorrect assumption. Your client was **parsing the access token** to read `name`/`email`. That was never safe, and switching the server from JWT access tokens to reference tokens simply made the latent bug visible.

## The core rule: access tokens are opaque to clients

An access token is meant for **one audience: the API (resource server)**. Only the API should read/validate it. From the client's perspective the access token must be treated as an **opaque string** — you forward it in the `Authorization: Bearer` header and never look inside it.

This is exactly why your app broke:

- With **JWT** access tokens, parsing *happened* to work — the claims were sitting there in a decodable JWT.
- With **reference** tokens, the access token is an opaque random identifier with no readable claims, so `JwtSecurityTokenHandler.ReadJwtToken(...)` throws or yields nothing.

A server can switch token formats at any time. Client code that depends on the access token being a JWT is fragile by design.

## Where user identity actually comes from

There are two correct sources for `name` and `email` in a client:

### 1. The ID token (primary)

The **ID token** is the token designed to prove **user identity to the client**. It's always a JWT, and identity claims (`sub`, `name`, `email`, etc.) are delivered here when you request the matching scopes (`openid`, `profile`, `email`).

In ASP.NET Core with the OpenID Connect handler you don't parse it yourself — the middleware validates the ID token and surfaces the claims on `User`:

```csharp
builder.Services.AddAuthentication(options =>
{
    options.DefaultScheme = CookieAuthenticationDefaults.AuthenticationScheme;
    options.DefaultChallengeScheme = "oidc";
})
.AddCookie()
.AddOpenIdConnect("oidc", options =>
{
    options.Authority = "https://identity.example.com";
    options.ClientId = "web.app";
    options.ClientSecret = "secret";
    options.ResponseType = "code";
    options.Scope.Add("openid");
    options.Scope.Add("profile");
    options.Scope.Add("email");
    options.GetClaimsFromUserInfoEndpoint = true; // pull extra claims from userinfo
    options.SaveTokens = true;
});
```

```csharp
// Read identity from the validated ID token / user principal — NOT the access token
var name  = User.Identity?.Name;
var email = User.FindFirst("email")?.Value;
var sub   = User.FindFirst("sub")?.Value;
```

### 2. The userinfo endpoint (for additional claims)

If you need claims that aren't in the ID token, call the **userinfo endpoint** with the access token. It returns claims for the authenticated user:

```csharp
using IdentityModel.Client;

var disco = await httpClient.GetDiscoveryDocumentAsync("https://identity.example.com");

var userInfo = await httpClient.GetUserInfoAsync(new UserInfoRequest
{
    Address = disco.UserInfoEndpoint,
    Token = accessToken
});

var email = userInfo.Claims.FirstOrDefault(c => c.Type == "email")?.Value;
```

Setting `GetClaimsFromUserInfoEndpoint = true` (above) makes the OIDC handler do this for you automatically at login.

## The distinction to remember

| Token | Proves | Consumed by | Client should parse it? |
|-------|--------|-------------|--------------------------|
| **ID token** | *Who the user is* (authentication) | The **client** | Yes — that's its job (via the middleware) |
| **Access token** | *What may be called* (authorization) | The **API** | **No — opaque to the client** |

**Fix:** stop reading the access token. Request the `openid profile email` scopes, take `name`/`email` from the ID token (the user principal), and use the userinfo endpoint for anything extra. Your UI code then no longer cares whether the server issues JWT or reference access tokens.
