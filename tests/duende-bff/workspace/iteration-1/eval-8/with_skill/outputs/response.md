# Manual HTTP Calls with Token Management

Two patterns for making authenticated HTTP calls from a local BFF endpoint to a remote service.

## Pattern 1: Named HttpClient with Automatic Token Attachment

```csharp
// Registration
builder.Services.AddBff()
    .ConfigureOpenIdConnect(/* ... */);

builder.Services.AddUserAccessTokenHttpClient("remoteApiClient", configureClient: client =>
{
    client.BaseAddress = new Uri("https://remote-service.internal/");
});

// Endpoint
app.MapGet("/api/reports", async (IHttpClientFactory factory) =>
{
    var client = factory.CreateClient("remoteApiClient");
    // Token is automatically attached and refreshed by AccessTokenManagement
    var response = await client.GetAsync("reports");
    var data = await response.Content.ReadAsStringAsync();
    return Results.Text(data, "application/json");
})
.RequireAuthorization()
.AsBffApiEndpoint();
```

## Pattern 2: Manual GetUserAccessTokenAsync

```csharp
app.MapGet("/api/dashboard", async (HttpContext ctx, IHttpClientFactory factory) =>
{
    // Get the user's access token — automatically refreshed if expired
    var token = await ctx.GetUserAccessTokenAsync();

    var client = factory.CreateClient();
    client.SetBearerToken(token.AccessToken!);

    var response = await client.GetAsync("https://remote-service.internal/dashboard");
    var data = await response.Content.ReadAsStringAsync();
    return Results.Text(data, "application/json");
})
.RequireAuthorization()
.AsBffApiEndpoint();
```

## Key Points

- **`AddUserAccessTokenHttpClient`** creates a named `HttpClient` that automatically attaches the user's access token via a delegating handler. Token refresh is handled transparently by `Duende.AccessTokenManagement`.
- **`GetUserAccessTokenAsync`** retrieves the current user's access token manually. If the token is expired and a refresh token is available, it's refreshed automatically.
- **Both endpoints use `.AsBffApiEndpoint()`** for CSRF protection — this is required for any BFF endpoint called from the SPA.
- **Never return the raw token to the browser** — that defeats the entire BFF pattern. The token stays server-side.
