Use `RequiredTokenType.UserOrNone`.

```csharp
app.MapRemoteBffApiEndpoint("/api/reports", new Uri("https://api.example.com/reports"))
   .WithAccessToken(RequiredTokenType.UserOrNone);
```

- `User`: requires a logged-in user, otherwise 401.
- `Client`: uses a client-credentials token.
- `UserOrClient`: user token if present, else client token.
- `UserOrNone`: user token if logged in, otherwise no token is attached and the request is still forwarded.
- `None`: never attach a token.

Anti-forgery (`X-CSRF: 1`) is still enforced by the proxy.
