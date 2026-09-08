# Customizing token retrieval per request in BFF v4

If subclassing `DefaultAccessTokenRetriever` no longer compiles, the most likely reason is that in v4 that class was **made internal (or sealed)**, so it's no longer part of the public extension surface you can derive from. You'll need to plug your custom logic in through a supported extension point instead of inheritance.

## Option A: a custom token-selecting message handler (most portable)

Since your goal is "pick a different token based on a custom header," a `DelegatingHandler` on the proxy's outbound `HttpClient` is a clean, version-independent way to do it. It inspects the incoming request, chooses the right token, and sets the `Authorization` header on the outgoing request:

```csharp
public class HeaderBasedTokenHandler : DelegatingHandler
{
    private readonly IHttpContextAccessor _accessor;
    public HeaderBasedTokenHandler(IHttpContextAccessor accessor) => _accessor = accessor;

    protected override async Task<HttpResponseMessage> SendAsync(
        HttpRequestMessage request, CancellationToken ct)
    {
        var http = _accessor.HttpContext!;
        var kind = http.Request.Headers["X-Token-Kind"].ToString();

        // Choose the token source based on the header
        var token = kind == "client"
            ? await http.GetClientAccessTokenAsync()
            : (await http.GetUserAccessTokenAsync())?.AccessToken;

        if (!string.IsNullOrEmpty(token))
            request.Headers.Authorization =
                new System.Net.Http.Headers.AuthenticationHeaderValue("Bearer", token);

        return await base.SendAsync(request, ct);
    }
}
```

Register it and attach it to the HttpClient the BFF proxy uses for that route.

## Option B: implement the token-retriever abstraction, if exposed

v4 exposes an abstraction for per-route token retrieval (rather than a base class to inherit). Look for an interface such as `IAccessTokenRetriever` (or similar) that you can implement and register on the endpoint. Implement its retrieval method to return the token you selected, and wire it up on the specific remote endpoint.

## Recommendation

- Confirm the exact public abstraction in your installed `Duende.BFF` version — the class was locked down, so switch from inheritance to composition (an interface implementation or a delegating handler).
- The header-based `DelegatingHandler` in Option A works regardless of the exact internal API and gives you full control over which token is attached per request.

Check the Duende BFF v4 upgrade notes for the precise replacement type and registration method for custom token retrieval.
