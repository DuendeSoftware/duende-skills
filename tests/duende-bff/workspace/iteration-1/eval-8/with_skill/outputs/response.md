# Manual Token Management in BFF Local API Endpoints

Here are two patterns for calling a remote service from a local BFF endpoint with automatic token refresh, without using `MapRemoteBffApiEndpoint`.

## Pattern 1: Named HttpClient with Automatic Token Attachment (Preferred)

Register a named HTTP client with `AddUserAccessTokenHttpClient`. This automatically attaches the user's access token to every outgoing request and handles refresh transparently via `Duende.AccessTokenManagement`.

```csharp
// Service registration
builder.Services.AddBff()
    .ConfigureOpenIdConnect(options =>
    {
        options.Authority = "https://idp.example.com";
        options.ClientId = "bff-client";
        options.ClientSecret = "secret";
        options.ResponseType = "code";
        options.SaveTokens = true;
        options.Scope.Add("openid");
        options.Scope.Add("profile");
        options.Scope.Add("offline_access");
    });

// Named HttpClient with automatic user access token management
builder.Services.AddUserAccessTokenHttpClient("remoteService", configureClient: client =>
{
    client.BaseAddress = new Uri("https://remote-service.example.com/");
});
```

```csharp
// Endpoint using the named HttpClient
app.MapGet("/api/data", async (IHttpClientFactory factory) =>
{
    var client = factory.CreateClient("remoteService"); // Token attached automatically
    var response = await client.GetAsync("data");
    var content = await response.Content.ReadAsStringAsync();
    return Results.Text(content);
})
.RequireAuthorization()
.AsBffApiEndpoint();
```

## Pattern 2: Manual Token Retrieval with GetUserAccessTokenAsync

For more control, retrieve the token manually using `GetUserAccessTokenAsync` and attach it with `SetBearerToken`. Token refresh is still handled automatically by AccessTokenManagement — if the current token is expired, the refresh token is used to obtain a new one before returning.

```csharp
app.MapGet("/api/data-manual", async (HttpContext ctx, IHttpClientFactory factory) =>
{
    // AccessTokenManagement handles refresh automatically if the token is expired
    var token = await ctx.GetUserAccessTokenAsync();

    var client = factory.CreateClient();
    client.SetBearerToken(token);

    var response = await client.GetAsync("https://remote-service.example.com/data");
    var content = await response.Content.ReadAsStringAsync();
    return Results.Text(content);
})
.RequireAuthorization()
.AsBffApiEndpoint();
```

## Important: Never Expose Tokens to the Browser

Both patterns keep the access token server-side. **Never** return the raw token to JavaScript — this defeats the entire purpose of the BFF pattern:

```csharp
// ❌ DO NOT DO THIS — exposes token to the browser
app.MapGet("/api/token", async (HttpContext ctx) =>
{
    var token = await ctx.GetUserAccessTokenAsync();
    return Results.Json(new { accessToken = token }); // ❌ Token leaked to frontend
});
```

## Key Points

- **Token refresh is automatic**: `Duende.AccessTokenManagement` transparently refreshes expired tokens using the refresh token stored in the server-side session. You don't need to implement any refresh logic.
- **Both patterns require `.AsBffApiEndpoint()`** to enforce CSRF protection via the `X-CSRF: 1` header.
- **Pattern 1 is preferred** when you just need to forward requests — less boilerplate and no risk of forgetting to attach the token.
- **Pattern 2 is useful** when you need to inspect the token, call multiple services with different tokens, or apply custom logic before making the request.
