# Don't Parse Access Tokens in the Client

## The Problem

Your client application broke because it was **parsing the access token as a JWT** to extract user claims. When the server switched to reference tokens (opaque strings), JWT parsing fails because reference tokens are not JWTs.

This reveals a fundamental misuse of tokens: **clients should treat access tokens as opaque strings**, regardless of their actual format.

## Why Clients Should Not Parse Access Tokens

Access tokens are designed to be consumed by the **resource server (API)**, not the client. The OIDC specification is clear:

- **Access tokens** authorize API calls → consumed by the **API**
- **ID tokens** prove user identity → consumed by the **client**

| Token | Consumed By | Purpose |
|-------|-------------|---------|
| ID Token | Client application | User identity (name, email, sub) |
| Access Token | Resource server (API) | Authorization for API access |
| Refresh Token | Client application | Obtain new access tokens |

When a client parses an access token, it creates a tight coupling to the token format. The server is free to change from JWT to reference tokens (or change the JWT claims structure) without notice — the access token format is an implementation detail between the authorization server and the API.

## The Correct Way to Get User Info

### Option 1: ID Token (Primary)

The ID token is a JWT that the client is explicitly designed to consume. It contains user identity claims:

```csharp
// In an ASP.NET Core app using OIDC authentication,
// user claims from the ID token are available via the ClaimsPrincipal:
var name = User.FindFirst("name")?.Value;
var email = User.FindFirst("email")?.Value;
var sub = User.FindFirst("sub")?.Value;
```

To get `name` and `email` in the ID token, request the `profile` and `email` scopes:

```csharp
options.Scope.Add("profile");
options.Scope.Add("email");
```

### Option 2: UserInfo Endpoint

If the ID token doesn't contain all the claims you need (some providers send minimal ID tokens and defer claims to the userinfo endpoint), you can call the userinfo endpoint:

```csharp
var disco = await httpClient.GetDiscoveryDocumentAsync(authority);
var userInfoResponse = await httpClient.GetUserInfoAsync(new UserInfoRequest
{
    Address = disco.UserInfoEndpoint,
    Token = accessToken  // Use the access token to authenticate
});

var name = userInfoResponse.Claims.FirstOrDefault(c => c.Type == "name")?.Value;
```

Or configure the OIDC handler to call userinfo automatically:

```csharp
options.GetClaimsFromUserInfoEndpoint = true;
```

## Key Takeaway

- **Never parse access tokens in client code.** Treat them as opaque.
- **Use the ID token** for user identity claims in the client.
- **Use the userinfo endpoint** as a fallback for additional claims.
- **ID tokens prove identity** (consumed by clients); **access tokens authorize API calls** (consumed by APIs).
