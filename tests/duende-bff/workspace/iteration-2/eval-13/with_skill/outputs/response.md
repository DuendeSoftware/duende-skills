In BFF v4, `DefaultAccessTokenRetriever` was made **internal** — you can no longer inherit from it. Instead, you must implement the `IAccessTokenRetriever` interface directly.

Here's how to implement a custom token retriever that selects tokens based on a custom header:

```csharp
// CustomHeaderTokenRetriever.cs
public class CustomHeaderTokenRetriever : IAccessTokenRetriever
{
    private readonly IHttpContextAccessor _httpContextAccessor;

    public CustomHeaderTokenRetriever(IHttpContextAccessor httpContextAccessor)
    {
        _httpContextAccessor = httpContextAccessor;
    }

    public async Task<AccessTokenResult> GetAccessToken(GetAccessTokenContext context)
    {
        var httpContext = _httpContextAccessor.HttpContext;
        var customHeader = httpContext?.Request.Headers["X-Token-Scope"].FirstOrDefault();

        if (customHeader == "client")
        {
            // Use client credentials token
            var clientToken = await httpContext!.GetClientAccessTokenAsync();
            if (!string.IsNullOrEmpty(clientToken))
            {
                return new BearerTokenResult(clientToken, "Bearer");
            }
            return new AccessTokenRetrievalError("No client token available");
        }

        // Default: use user token
        var userToken = await httpContext!.GetUserAccessTokenAsync();
        if (!string.IsNullOrEmpty(userToken))
        {
            return new BearerTokenResult(userToken, "Bearer");
        }

        return new NoAccessTokenResult();
    }
}
```

Register the custom retriever on a specific endpoint:

```csharp
app.MapRemoteBffApiEndpoint("/api/custom", new Uri("https://api.example.com"))
    .WithAccessToken(RequiredTokenType.User)
    .WithAccessTokenRetriever<CustomHeaderTokenRetriever>();
```

Key points:

1. **`DefaultAccessTokenRetriever` is internal in v4** — Cannot be inherited. You must implement `IAccessTokenRetriever` directly.

2. **`IAccessTokenRetriever` has a single method**: `Task<AccessTokenResult> GetAccessToken(GetAccessTokenContext context)`

3. **`AccessTokenResult` implementations**:
   - `BearerTokenResult` — contains the token string and scheme
   - `DPoPTokenResult` — for DPoP proof-of-possession tokens
   - `NoAccessTokenResult` — when no token is available (anonymous)
   - `AccessTokenRetrievalError` — when token retrieval fails

4. **Register via `.WithAccessTokenRetriever<T>()`** on the remote API endpoint.
