# Don't Parse Access Tokens in the Client

## The Problem

You were parsing the access token JWT to get user claims. When the token format changed to a reference token (opaque string), the parsing broke. But even before that, this approach had issues.

## Why You Shouldn't Parse Access Tokens

Access tokens are meant for the API (resource server), not for the client application. Clients should treat access tokens as opaque strings - just pass them along to the API without looking inside.

The proper way to get user information in a client app:

### Use the ID Token

The ID token is specifically designed for the client to learn about the user. It contains claims like `name`, `email`, `sub`, etc.

In ASP.NET Core with the OIDC middleware, these claims are automatically available:

```csharp
var name = User.FindFirst("name")?.Value;
var email = User.FindFirst("email")?.Value;
```

Make sure you're requesting the right scopes: `openid`, `profile`, `email`.

### Use the UserInfo Endpoint

If you need additional claims that aren't in the ID token, you can call the userinfo endpoint:

```csharp
using IdentityModel.Client;

var disco = await httpClient.GetDiscoveryDocumentAsync(authority);
var userInfo = await httpClient.GetUserInfoAsync(new UserInfoRequest
{
    Address = disco.UserInfoEndpoint,
    Token = accessToken
});

var name = userInfo.Claims.FirstOrDefault(c => c.Type == "name")?.Value;
```

## Summary

- **ID tokens** are for the client - they prove who the user is
- **Access tokens** are for the API - they authorize API calls
- Don't parse access tokens in client code
- Use the ID token claims or the userinfo endpoint for user information
