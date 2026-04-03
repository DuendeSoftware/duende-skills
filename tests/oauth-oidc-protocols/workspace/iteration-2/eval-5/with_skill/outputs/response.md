# Don't Parse Access Tokens in the Client

## What Went Wrong

Your client application was parsing the access token JWT to read user claims (name, email). This broke when the server switched to reference tokens because **reference tokens are opaque strings** — they can't be parsed as JWTs. But even before the format change, this approach was architecturally incorrect.

## The Core Rule: Clients Should Treat Access Tokens as Opaque

**Clients should never parse access tokens.** Only the **resource server (API)** should validate and inspect access tokens. The access token's audience is the API, not the client. From the client's perspective, the access token is just a string to pass along in the `Authorization` header.

This is a fundamental OAuth 2.0 / OIDC principle:

| Token | Purpose | Who consumes it |
|-------|---------|----------------|
| **ID Token** | Proves user identity | **Client application** |
| **Access Token** | Authorizes API calls | **Resource server (API)** |
| **Refresh Token** | Gets new access tokens | **Client application** |

The **ID token** is specifically designed to prove the user's identity to the client. It's always a JWT, it always contains identity claims (`sub`, `name`, `email` if the right scopes are requested), and its audience is the client.

## The Correct Approach

### Option 1: Use the ID Token (Recommended)

The ID token is what you should use for displaying user information in the client UI. When using ASP.NET Core's OIDC authentication middleware, the ID token claims are automatically mapped into the `ClaimsPrincipal`:

```csharp
// In a Razor page or controller
var userName = User.FindFirst("name")?.Value;
var email = User.FindFirst("email")?.Value;
```

Make sure you request the appropriate scopes:
- `openid` — required for OIDC, gives you the `sub` claim
- `profile` — gives you `name`, `family_name`, `given_name`, etc.
- `email` — gives you `email` and `email_verified`

### Option 2: Call the UserInfo Endpoint

If you need claims that aren't in the ID token (e.g., because of token size optimization or because the server only includes minimal claims in the ID token), you can call the **userinfo endpoint**:

```csharp
using IdentityModel.Client;

// Fetch the discovery document
var disco = await httpClient.GetDiscoveryDocumentAsync(authority);

// Call the userinfo endpoint with the access token
var userInfoResponse = await httpClient.GetUserInfoAsync(new UserInfoRequest
{
    Address = disco.UserInfoEndpoint,
    Token = accessToken  // Use the access token to authenticate, but don't parse it
});

if (!userInfoResponse.IsError)
{
    var name = userInfoResponse.Claims.FirstOrDefault(c => c.Type == "name")?.Value;
    var email = userInfoResponse.Claims.FirstOrDefault(c => c.Type == "email")?.Value;
}
```

### What NOT to Do

```csharp
// ❌ WRONG — Clients should never parse access tokens
var handler = new JwtSecurityTokenHandler();
var jwt = handler.ReadJwtToken(accessToken);
var name = jwt.Claims.First(c => c.Type == "name").Value;
// This breaks when the server switches to reference tokens!
// And it was never correct even with JWTs.

// ✅ CORRECT — Use the ID token claims or the userinfo endpoint
var name = User.FindFirst("name")?.Value;
```
