Here are both patterns for making HTTP calls from a local BFF endpoint using the logged-in user's access token:

## Pattern 1: Named HttpClient with Automatic Token Attachment

```csharp
// Program.cs — Service registration
builder.Services.AddBff()
    .ConfigureOpenIdConnect(options => { /* ... */ });

// Register a named HTTP client that automatically attaches the user's access token
builder.Services.AddUserAccessTokenHttpClient("remoteApi", configureClient: client =>
{
    client.BaseAddress = new Uri("https://remote-service.internal/");
});

// Local BFF endpoint using the named client
app.MapGet("/api/data", async (IHttpClientFactory factory) =>
{
    var client = factory.CreateClient("remoteApi"); // Token attached automatically
    var response = await client.GetAsync("data");
    var content = await response.Content.ReadAsStringAsync();
    return Results.Text(content, "application/json");
})
.RequireAuthorization()
.AsBffApiEndpoint();
```

## Pattern 2: Manual GetUserAccessTokenAsync

```csharp
// Local BFF endpoint using manual token retrieval
app.MapGet("/api/data-manual", async (HttpContext ctx, IHttpClientFactory factory) =>
{
    // ATM handles refresh automatically if the token is expired
    var token = await ctx.GetUserAccessTokenAsync();

    var client = factory.CreateClient();
    client.SetBearerToken(token);

    var response = await client.GetAsync("https://remote-service.internal/data");
    var content = await response.Content.ReadAsStringAsync();
    return Results.Text(content, "application/json");
})
.RequireAuthorization()
.AsBffApiEndpoint();
```

Key points:

1. **Both patterns use `.AsBffApiEndpoint()`** for CSRF protection — this is mandatory for all BFF local API endpoints.

2. **`AddUserAccessTokenHttpClient`** is the preferred pattern — it automatically retrieves and attaches the user's access token (and refreshes it if expired) via `Duende.AccessTokenManagement`.

3. **`GetUserAccessTokenAsync`** is the manual approach — useful when you need conditional logic before attaching the token.

4. **Token refresh is handled automatically** by AccessTokenManagement in both cases. When the access token expires, ATM uses the stored refresh token to obtain a new one transparently.

5. **Never return the raw access token to the browser** — the whole point of BFF is keeping tokens server-side. Do not do `Results.Json(new { accessToken = token })`.
