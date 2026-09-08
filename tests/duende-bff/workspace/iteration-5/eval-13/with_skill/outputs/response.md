# Custom token retriever in BFF v4

## What changed

In **v4, `DefaultAccessTokenRetriever` was made `internal`** — you can no longer inherit from it the way you did in v3. Instead, you implement the **`IAccessTokenRetriever`** interface directly and register your implementation per-endpoint with **`.WithAccessTokenRetriever<T>()`**.

## Implement `IAccessTokenRetriever`

The interface has a single `GetAccessToken` method that receives a `GetAccessTokenContext` and returns an `AccessTokenResult`. You return one of the concrete `AccessTokenResult` implementations depending on what you resolved:

- `BearerTokenResult` — a bearer access token
- `DPoPTokenResult` — a DPoP-bound token
- `NoAccessTokenResult` — deliberately send no token
- `AccessTokenRetrievalError` — signal a failure

```csharp
using Duende.Bff;
using Duende.Bff.AccessTokenManagement;

public class HeaderBasedTokenRetriever : IAccessTokenRetriever
{
    public async Task<AccessTokenResult> GetAccessToken(GetAccessTokenContext context)
    {
        var http = context.HttpContext;

        // Select a token based on your custom header
        if (http.Request.Headers.TryGetValue("X-Token-Kind", out var kind) &&
            kind == "client")
        {
            var clientToken = await http.GetClientAccessTokenAsync();
            return clientToken is not null
                ? new BearerTokenResult(clientToken)
                : new AccessTokenRetrievalError("No client token available");
        }

        // Default: use the current user's token
        var userToken = await http.GetUserAccessTokenAsync();
        if (userToken?.AccessToken is null)
            return new NoAccessTokenResult();

        return new BearerTokenResult(userToken.AccessToken);
    }
}
```

## Register it on the endpoint

```csharp
builder.Services.AddBff()
    .AddRemoteApis();

app.MapRemoteBffApiEndpoint("/api/custom", new Uri("https://api.example.com"))
    .WithAccessToken(RequiredTokenType.User)
    .WithAccessTokenRetriever<HeaderBasedTokenRetriever>();   // ✅ per-endpoint override
```

## Summary of the v3 → v4 change

| v3 | v4 |
|---|---|
| Inherit `DefaultAccessTokenRetriever` | Implement `IAccessTokenRetriever` directly |
| — | `DefaultAccessTokenRetriever` is now `internal` |
| Override base behavior | Return an `AccessTokenResult` (`BearerTokenResult` / `DPoPTokenResult` / `NoAccessTokenResult` / `AccessTokenRetrievalError`) |
| Global registration | Per-endpoint `.WithAccessTokenRetriever<T>()` |

That's the idiomatic v4 way to select a token per-route based on your custom header.
