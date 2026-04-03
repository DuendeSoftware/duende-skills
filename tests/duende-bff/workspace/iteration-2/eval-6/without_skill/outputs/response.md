For an endpoint that should work for both authenticated and anonymous users, you'll want a token type that optionally includes the user's token without requiring authentication.

In Duende BFF, I believe you'd configure the remote endpoint with an optional token type. Something like this:

```csharp
app.MapRemoteBffApiEndpoint("/api/reports", new Uri("https://reports-service.internal/api"))
    .WithAccessToken(RequiredTokenType.UserOrClient);
```

This should forward the user's token if they're logged in, or fall back to a client credentials token if they're anonymous. That way, anonymous users still get access but through the machine-to-machine flow.

Alternatively, you could try `RequiredTokenType.None` and handle token attachment conditionally in the downstream service, but that seems less elegant.
