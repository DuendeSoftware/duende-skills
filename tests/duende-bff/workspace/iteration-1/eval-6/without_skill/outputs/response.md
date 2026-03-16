# Optional Token for /api/reports

For an endpoint that should work for both authenticated and anonymous users, you want to use an optional token mode.

```csharp
app.MapRemoteBffApiEndpoint("/api/reports", new Uri("https://reports-service.internal/api"))
    .WithAccessToken(RequiredTokenType.UserOrNone);
```

`RequiredTokenType.UserOrNone` will:
- Attach the user's access token if they're logged in
- Send no token if they're anonymous, without triggering a login challenge

This is different from `RequiredTokenType.User` which would force a login redirect for anonymous users.
