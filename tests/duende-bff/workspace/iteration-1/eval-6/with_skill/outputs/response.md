# Optional Authentication for /api/reports

Use `RequiredTokenType.UserOrNone` — it forwards the user's access token if they're logged in, but does **not** trigger an authentication challenge for anonymous visitors. Anonymous requests are proxied without a token.

```csharp
builder.Services.AddBff()
    .ConfigureOpenIdConnect(options =>
    {
        // ... OIDC config
    })
    .AddRemoteApis();

// ...

app.MapRemoteBffApiEndpoint("/api/reports", new Uri("https://reports-service.internal/api"))
    .WithAccessToken(RequiredTokenType.UserOrNone);
```

## Token Type Options

| `RequiredTokenType` | Behavior |
|---|---|
| `None` | No token attached; anonymous passthrough |
| `User` | Forwards user token; **challenges if unauthenticated** |
| `Client` | Forwards client credentials token |
| `UserOrClient` | User token if available, falls back to client token |
| `UserOrNone` | User token if logged in, no token if anonymous (**no challenge**) |

**Do NOT use `RequiredTokenType.User`** — it would trigger a login challenge for anonymous visitors, which is not what you want. `UserOrNone` is the correct choice for endpoints that serve both authenticated and anonymous users.
