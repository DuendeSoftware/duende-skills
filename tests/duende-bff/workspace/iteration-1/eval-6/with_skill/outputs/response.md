# Optional User Token for Anonymous-Friendly Endpoints

Use `RequiredTokenType.UserOrNone` — it forwards the user's access token if they're logged in, but does **not** trigger an authentication challenge for anonymous users. Anonymous requests are forwarded without any token.

```csharp
builder.Services.AddBff()
    .ConfigureOpenIdConnect(/* ... */)
    .AddRemoteApis();

// /api/reports works for both authenticated and anonymous users
app.MapRemoteBffApiEndpoint("/api/reports", new Uri("https://reports-service.internal/api"))
    .WithAccessToken(RequiredTokenType.UserOrNone);
```

## Token Type Comparison

| `RequiredTokenType` | Authenticated User | Anonymous User |
|---|---|---|
| `User` | Forwards user token | Returns 401 challenge |
| `UserOrNone` | Forwards user token | Forwards without token (no challenge) |
| `None` | No token | No token |
| `Client` | Client credentials token | Client credentials token |
| `UserOrClient` | User token | Falls back to client token |

`RequiredTokenType.UserOrNone` is the correct choice when the downstream API can handle both authenticated and unauthenticated requests, and you don't want to force a login for anonymous visitors.
