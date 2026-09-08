# Calling a remote API from a local BFF endpoint with the user's token

Here are both patterns. In both, the endpoint is a **local BFF API endpoint** (`.AsBffApiEndpoint()` for CSRF protection), and the raw access token is **never** returned to the browser — only the downstream API's data is. Token refresh is handled automatically by `Duende.AccessTokenManagement` (because `SaveTokens = true` on the OIDC handler).

## Pattern 1 — Named `HttpClient` with automatic token attachment (preferred)

`AddUserAccessTokenHttpClient` builds a named client that automatically attaches the current user's access token (and refreshes it when expired):

```csharp
using Duende.Bff;

// Registration
builder.Services.AddUserAccessTokenHttpClient("remoteApi", configureClient: client =>
{
    client.BaseAddress = new Uri("https://remote-service/");
});

// Endpoint — token is attached for you
app.MapGet("/api/data", async (IHttpClientFactory factory) =>
{
    var client = factory.CreateClient("remoteApi");   // user token attached automatically
    var body = await client.GetStringAsync("data");
    return Results.Text(body);                          // ✅ return data, not the token
})
.RequireAuthorization()
.AsBffApiEndpoint();
```

## Pattern 2 — Manual `GetUserAccessTokenAsync` + `SetBearerToken`

When you want to make the call yourself, pull the token from the session with `GetUserAccessTokenAsync()`. AccessTokenManagement refreshes it transparently if it's expired:

```csharp
using Duende.Bff;
using Duende.AccessTokenManagement.OpenIdConnect;
using IdentityModel.Client; // SetBearerToken

app.MapGet("/api/data-manual", async (HttpContext ctx, IHttpClientFactory factory) =>
{
    // Auto-refreshed if expired — no manual refresh logic needed
    var token = await ctx.GetUserAccessTokenAsync();

    var client = factory.CreateClient();
    client.SetBearerToken(token.AccessToken);

    var response = await client.GetAsync("https://remote-service/data");
    var body = await response.Content.ReadAsStringAsync();

    return Results.Text(body);                          // ✅ return data, not the token
})
.RequireAuthorization()
.AsBffApiEndpoint();
```

## Key points

- **Both endpoints** use `.AsBffApiEndpoint()` so the `X-CSRF` anti-forgery header is enforced.
- **Automatic refresh:** `GetUserAccessTokenAsync()` and the `AddUserAccessTokenHttpClient` client both go through AccessTokenManagement, which refreshes the access token using the stored refresh token when needed — you never call the token endpoint yourself.
- **Never expose the token:** return the downstream response body, not the token. Something like `Results.Json(new { accessToken = token })` would defeat the entire BFF pattern.
- **Prefer Pattern 1** for most cases — it centralizes token handling on the client. Use Pattern 2 when you need custom per-call logic.
