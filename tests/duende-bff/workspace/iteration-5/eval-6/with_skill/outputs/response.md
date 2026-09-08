# `/api/reports` for both authenticated and anonymous users

Use **`RequiredTokenType.UserOrNone`**.

That's exactly the semantics you described:

- **Logged-in user** → the BFF attaches their access token (refreshed automatically) when forwarding to the downstream API.
- **Anonymous visitor** → the BFF forwards the request with **no token** and does **not** issue an authentication challenge. The endpoint just works, unauthenticated.

```csharp
using Duende.Bff;

builder.Services.AddBff()
    .AddRemoteApis();

app.MapRemoteBffApiEndpoint("/api/reports", new Uri("https://reports-service/api"))
    .WithAccessToken(RequiredTokenType.UserOrNone);   // ✅ token if logged in, none if not
```

## Why not `RequiredTokenType.User`?

`RequiredTokenType.User` **requires** a logged-in user and will **challenge** (trigger an OIDC redirect / 401) when the caller is anonymous — so your anonymous visitors would be blocked instead of getting an unauthenticated response. That's the opposite of what you want here.

## Token type quick reference

| `RequiredTokenType` | Anonymous caller | Logged-in caller |
|---|---|---|
| `User` | **Challenged** (blocked) | User token attached |
| `UserOrNone` | No token, no challenge ✅ | User token attached ✅ |
| `UserOrClient` | Client token attached | User token attached |
| `Client` | Client token attached | Client token attached |
| `None` | No token | No token |

`UserOrNone` is the v4 name; it replaces v3's `OptionalUserToken`. It's the right choice whenever an endpoint must serve both authenticated and anonymous callers and should simply omit the token for anonymous ones.
