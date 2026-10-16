# Custom token retriever in BFF v4

**What changed:** `DefaultAccessTokenRetriever` is now `internal`, so you can't inherit it. Implement `IAccessTokenRetriever` directly and register it per endpoint.

```csharp
public class HeaderTokenRetriever : IAccessTokenRetriever
{
    public Task<AccessTokenResult> GetAccessToken(GetAccessTokenContext context)
    {
        // choose behaviour based on request context, e.g. a custom header
        var choice = context.HttpContext.Request.Headers["X-Token-Choice"].ToString();

        // Select the token you want from your own logic. context.UserToken is the user's token.
        // For the "alternate" case, obtain a different token (e.g. client credentials via ATM) here.
        return Task.FromResult<AccessTokenResult>(
            new BearerTokenResult(context.UserToken, "Bearer"));
    }
}

builder.Services.AddTransient<HeaderTokenRetriever>();   // if it has dependencies

app.MapRemoteBffApiEndpoint("/api/custom", new Uri("https://api.example.com"))
    .WithAccessToken(RequiredTokenType.User)
    .WithAccessTokenRetriever<HeaderTokenRetriever>();
```

Notes: the v3 `RequireAccessToken(TokenType.User)` became `WithAccessToken(RequiredTokenType.User)`. Don't return tokens to the browser. Anti-forgery (`X-CSRF: 1`) is still enforced. The exact shape of `GetAccessTokenContext` and result types should be checked against the version you're on.
