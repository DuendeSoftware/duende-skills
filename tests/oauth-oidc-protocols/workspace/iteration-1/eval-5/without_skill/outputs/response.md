# Getting User Info Without Parsing Access Tokens

## The Issue

You shouldn't parse access tokens in your client application. Access tokens are meant for APIs, not clients. When the format changed from JWT to reference token, your code broke because reference tokens aren't parseable JWTs.

## Correct Approaches

### Use the ID Token
The ID token contains user identity claims like name and email:

```csharp
var name = User.FindFirst("name")?.Value;
var email = User.FindFirst("email")?.Value;
```

Make sure you request the appropriate scopes (`profile`, `email`).

### Use the UserInfo Endpoint
You can also call the UserInfo endpoint to get user claims:

```csharp
var userInfo = await httpClient.GetUserInfoAsync(new UserInfoRequest
{
    Address = disco.UserInfoEndpoint,
    Token = accessToken
});
```

## Token Roles

- **ID Token**: For the client — proves who the user is
- **Access Token**: For the API — authorizes access
- **Refresh Token**: For the client — gets new access tokens

Access tokens should be treated as opaque by clients.
