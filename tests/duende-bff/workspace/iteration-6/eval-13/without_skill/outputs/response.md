In v4 the token retrieval was reworked. `DefaultAccessTokenRetriever` is no longer a base class to inherit; instead you implement the interface `IAccessTokenRetriever` directly and register it per endpoint.

```csharp
public class HeaderTokenRetriever(IHttpContextAccessor accessor) : IAccessTokenRetriever
{
    public async Task<AccessTokenResult> GetAccessToken(AccessTokenRetrievalContext context)
    {
        var http = context.HttpContext;
        var which = http.Request.Headers["X-Token-Type"].ToString();
        var type = which == "client" ? TokenType.Client : TokenType.User;
        var token = type == TokenType.Client
            ? await http.GetClientAccessTokenAsync()
            : await http.GetUserAccessTokenAsync();
        if (token.IsError) return new AccessTokenResult { Error = token.Error };
        return new BearerTokenResult { AccessToken = token.AccessToken! };
    }
}

builder.Services.AddTransient<HeaderTokenRetriever>();
app.MapRemoteBffApiEndpoint("/api", new Uri("https://api.example.com"))
   .WithAccessToken(RequiredTokenType.User)
   .WithAccessTokenRetriever<HeaderTokenRetriever>();
```
Exact result types may differ slightly; check the v4 upgrade guide.
