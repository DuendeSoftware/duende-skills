# Optional Token for API Endpoints

For endpoints that should work both for authenticated and anonymous users, you can configure the token type to be optional.

```csharp
app.MapRemoteBffApiEndpoint("/api/reports", new Uri("https://reports-service.internal/api"))
    .WithOptionalUserAccessToken();
```

Or you could use:

```csharp
app.MapRemoteBffApiEndpoint("/api/reports", new Uri("https://reports-service.internal/api"))
    .WithAccessToken(RequiredTokenType.UserOrNone);
```

This will attach the user's access token if they're logged in, but won't challenge them if they're anonymous. The request will be forwarded without a token for unauthenticated users.
