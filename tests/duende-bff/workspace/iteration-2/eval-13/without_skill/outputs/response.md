In earlier versions of Duende BFF, you could inherit from `DefaultAccessTokenRetriever` to customize token retrieval. If that's no longer working, you'll need to implement the token retriever interface directly.

Here's a general approach:

```csharp
public class CustomTokenRetriever : IAccessTokenRetriever
{
    public async Task<AccessTokenResult> GetAccessToken(GetAccessTokenContext context)
    {
        var httpContext = context.HttpContext;
        var customHeader = httpContext.Request.Headers["X-Token-Scope"].FirstOrDefault();

        // Custom logic based on header
        if (customHeader == "client")
        {
            // Get client token somehow
            return new BearerTokenResult("client-token", "Bearer");
        }

        // Default user token
        var token = await httpContext.GetUserAccessTokenAsync();
        return new BearerTokenResult(token, "Bearer");
    }
}

// Registration
app.MapRemoteBffApiEndpoint("/api/custom", new Uri("https://api.example.com"))
    .WithAccessTokenRetriever<CustomTokenRetriever>();
```

The key change is that you implement the interface directly rather than inheriting from the base class.
