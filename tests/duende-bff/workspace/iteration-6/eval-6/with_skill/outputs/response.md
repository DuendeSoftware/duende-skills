Use **`RequiredTokenType.UserOrNone`** (it replaces v3's `OptionalUserToken`).

```csharp
app.MapRemoteBffApiEndpoint("/api/reports", new Uri("https://reports-service/api"))
   .WithAccessToken(RequiredTokenType.UserOrNone);
```

| Type | Behaviour |
|---|---|
| `None` | no token, anonymous passthrough |
| `User` | user token; challenges if unauthenticated |
| `Client` | client-credentials token, no user needed |
| `UserOrClient` | user token, else client token |
| `UserOrNone` | user token if logged in, otherwise none — **no challenge** |

Anti-forgery is still enforced, so the SPA must send `X-CSRF: 1`. For YARP routes the equivalent is `WithOptionalUserAccessToken()`.
