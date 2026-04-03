Use `RequiredTokenType.UserOrNone` for this scenario.

`UserOrNone` forwards the user's access token if the user is logged in, but if the user is anonymous, it simply sends **no token** without triggering an authentication challenge. This is exactly what you need for endpoints that should work for both authenticated and anonymous visitors.

```csharp
// Program.cs
builder.Services.AddBff()
    .ConfigureOpenIdConnect(options => { /* ... */ })
    .AddRemoteApis();

// ...

app.MapRemoteBffApiEndpoint("/api/reports", new Uri("https://reports-service.internal/api"))
    .WithAccessToken(RequiredTokenType.UserOrNone);
```

Here's how the different token types behave:

| `RequiredTokenType` | Logged in | Anonymous |
|---|---|---|
| `User` | Attaches user token | **Challenges** (redirects to login) |
| `UserOrNone` | Attaches user token | Sends no token (no challenge) |
| `Client` | Attaches client token | Attaches client token |
| `UserOrClient` | Attaches user token | Falls back to client token |
| `None` | No token | No token |

**Do NOT use `RequiredTokenType.User`** for this case — it would challenge anonymous users and redirect them to the IDP, which is not what you want for a mixed-auth endpoint.
