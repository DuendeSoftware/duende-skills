# Parsing Access Tokens in the Client — What's Wrong

## The Problem

Your application broke because you were parsing the access token as a JWT to extract user claims. When the server switched to reference tokens (opaque strings), the JWT parsing fails because reference tokens aren't JWTs — they're just random identifiers.

## The Root Issue

Access tokens are intended for the API (resource server), not for the client application. The format and contents of access tokens can change at any time — the server may switch between JWT and reference tokens, change claim names, or restructure the token entirely.

## The Correct Approach

### 1. Use the ID Token for User Claims

OpenID Connect issues an ID token specifically for the client application to identify the user. In ASP.NET Core, the OIDC middleware automatically processes the ID token and populates the `ClaimsPrincipal`:

```csharp
// Read user claims from the authentication result (populated from ID token)
var name = User.FindFirst("name")?.Value;
var email = User.FindFirst("email")?.Value;
```

### 2. Call the UserInfo Endpoint

If you need additional user information that isn't in the ID token, you can call the userinfo endpoint:

```csharp
// Configure the OIDC handler to fetch additional claims from userinfo
options.GetClaimsFromUserInfoEndpoint = true;
```

Or call it manually:

```csharp
var userInfoResponse = await httpClient.GetUserInfoAsync(new UserInfoRequest
{
    Address = disco.UserInfoEndpoint,
    Token = accessToken  // pass the access token (don't parse it)
});
```

### Key Takeaway

- The **ID token** is for the client — it tells you who the user is
- The **access token** is for the API — it authorizes what the user can access
- Access tokens should be treated as opaque strings by clients — never parsed or decoded
