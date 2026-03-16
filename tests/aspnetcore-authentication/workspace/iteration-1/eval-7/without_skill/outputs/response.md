# Cookie Size Exceeding 4KB Limit

## Problem

Authentication cookies can grow too large when you store tokens and many claims inside them. Browsers enforce a ~4KB limit per cookie, and when exceeded, the cookie gets silently truncated or rejected.

## Options

### 1. Reduce claims in the cookie

You can remove claims you don't need. The OIDC handler allows you to filter claims:

```csharp
.AddOpenIdConnect("oidc", options =>
{
    // Remove unnecessary claims
    options.ClaimActions.DeleteClaim("sid");
    options.ClaimActions.DeleteClaim("idp");
    options.ClaimActions.DeleteClaim("auth_time");
});
```

### 2. Use session storage

Instead of storing everything in the cookie, you can store the authentication ticket on the server side and only put a session identifier in the cookie. ASP.NET Core supports this through `ITicketStore`:

```csharp
.AddCookie("Cookies", options =>
{
    options.SessionStore = new MyTicketStore(); // Your implementation backed by a database or cache
});
```

This way the cookie only contains a session reference, keeping it well under the size limit.

### 3. Don't save tokens you don't need

If you don't need to call APIs on behalf of the user, you can set `SaveTokens = false` to avoid storing the access and refresh tokens in the cookie.

The tokens stored when `SaveTokens = true` include the access token, refresh token, and ID token, which can significantly increase cookie size.
