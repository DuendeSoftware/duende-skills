# Don't Parse Access Tokens in Client Apps

## The Problem

Parsing access tokens in a client application is fundamentally wrong, and your breakage after the server upgrade proves exactly why.

## Critical Rule: Clients Should Treat Access Tokens as Opaque

Access tokens — whether JWTs or reference tokens — are meant for the **resource server (API)**, not for the client application. Clients should treat access tokens as opaque strings. They should never parse, decode, or inspect them.

```csharp
// ❌ WRONG — Clients should treat access tokens as opaque
var handler = new JwtSecurityTokenHandler();
var jwt = handler.ReadJwtToken(accessToken);
var name = jwt.Claims.First(c => c.Type == "name").Value;
// This breaks when the server switches to reference tokens

// ✅ CORRECT — Only the resource server (API) validates access tokens
// The client just forwards the token in the Authorization header
httpClient.SetBearerToken(accessToken);
```

## Why It Breaks

When the server switched from JWT to reference tokens, the access token changed from a self-contained JWT (base64-encoded JSON) to an **opaque identifier** — a random string like `a5f3c8d2e1b4`. Trying to parse this as a JWT will fail because it's not valid JWT format. This is by design.

## The Correct Way to Get User Info

### Use the ID Token

The **ID token** is the correct place to get user identity claims (name, email, etc.) in the client application. This is what OpenID Connect was designed for:

- **ID tokens** prove user identity — consumed by the **client application**
- **Access tokens** authorize API calls — consumed by the **resource server (API)**

```csharp
// ✅ CORRECT — Read user claims from the ClaimsPrincipal
// (populated from the ID token by the OIDC middleware)
var name = User.FindFirst("name")?.Value;
var email = User.FindFirst("email")?.Value;
```

In ASP.NET Core with the OIDC middleware, the ID token claims are automatically mapped to the `ClaimsPrincipal` (`HttpContext.User`). You don't need to decode anything manually.

### Use the UserInfo Endpoint

If the ID token doesn't contain all the claims you need (some providers limit ID token claims by default), you can call the **userinfo endpoint**:

```csharp
// The userinfo endpoint returns user claims for the current access token
var userInfoEndpoint = disco.UserInfoEndpoint;
var userInfoResponse = await httpClient.GetUserInfoAsync(new UserInfoRequest
{
    Address = userInfoEndpoint,
    Token = accessToken
});

var name = userInfoResponse.Claims.FirstOrDefault(c => c.Type == "name")?.Value;
var email = userInfoResponse.Claims.FirstOrDefault(c => c.Type == "email")?.Value;
```

Or configure the OIDC handler to do it automatically:

```csharp
options.GetClaimsFromUserInfoEndpoint = true;
```

## Summary

| Token | Purpose | Who Consumes It | Format |
|-------|---------|----------------|--------|
| **ID Token** | Proves user identity | Client application | Always JWT |
| **Access Token** | Authorizes API calls | Resource server (API) | JWT or reference (opaque) |
| **Refresh Token** | Obtains new access tokens | Client application | Opaque handle |

The distinction is fundamental: **ID tokens prove who the user is (authentication)**, while **access tokens authorize what the user can do (authorization)**. Never confuse the two.
