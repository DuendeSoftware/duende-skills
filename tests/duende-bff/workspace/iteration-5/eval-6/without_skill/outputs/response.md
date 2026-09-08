# An endpoint that works for both logged-in and anonymous users

What you want is an **optional** user token: if the caller has a session, forward their access token to the downstream API; if not, just call the API without a token and don't force them to log in.

The key is **not** to use the "required user token" mode, because that treats an anonymous request as unauthorized and triggers a challenge/redirect. Instead, use the optional-user-token behavior.

```csharp
using Duende.Bff;

builder.Services.AddBff()
    .AddRemoteApis();

// Optional user token — attach it when present, otherwise proxy anonymously
app.MapRemoteBffApiEndpoint("/api/reports", new Uri("https://reports-service/api"))
    .WithOptionalUserAccessToken();
```

If your version exposes the token type as an enum on `WithAccessToken`, pick the value that means "optional" rather than the mandatory `User` value — e.g. `RequiredTokenType.None` combined with the optional-token extension, so anonymous callers are never challenged.

## Why not the required user token?

The "required user" token type forces authentication: an anonymous request gets challenged (a 401 or an OIDC redirect) instead of being proxied through. Since `/api/reports` must serve anonymous visitors too, that would break the anonymous path.

## Summary

- Don't require the user token — that challenges anonymous callers.
- Use the optional user-token behavior so the endpoint:
  - attaches the token when the user is logged in, and
  - proxies with no token (no challenge) when they're not.
