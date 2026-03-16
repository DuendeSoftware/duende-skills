# Calling a Remote Service with User Tokens in a BFF Endpoint

Here are two approaches to call a remote API with the logged-in user's access token from a local BFF endpoint.

## Pattern 1: Named HttpClient with Automatic Token Management

You can use `AddUserAccessTokenHttpClient` from Duende's AccessTokenManagement to register a named HTTP client that automatically attaches and refreshes the user's access token:

```csharp
// Service registration
builder.Services.AddUserAccessTokenHttpClient("remoteService", configureClient: client =>
{
    client.BaseAddress = new Uri("https://remote-service.example.com/");
});
```

```csharp
// Endpoint
app.MapGet("/api/data", async (IHttpClientFactory factory) =>
{
    var client = factory.CreateClient("remoteService"); // Token attached automatically
    var response = await client.GetAsync("data");
    var content = await response.Content.ReadAsStringAsync();
    return Results.Text(content);
})
.RequireAuthorization();
```

## Pattern 2: Manual Token Retrieval with GetUserAccessTokenAsync

For more control, retrieve the token manually:

```csharp
app.MapGet("/api/data-manual", async (HttpContext ctx, IHttpClientFactory factory) =>
{
    var token = await ctx.GetUserAccessTokenAsync();

    var client = factory.CreateClient();
    client.SetBearerToken(token);

    var response = await client.GetAsync("https://remote-service.example.com/data");
    var content = await response.Content.ReadAsStringAsync();
    return Results.Text(content);
})
.RequireAuthorization();
```

## Token Refresh

Both approaches benefit from Duende.AccessTokenManagement, which automatically handles token refresh when the access token is expired. You don't need to implement refresh logic yourself.

## Notes

- Make sure `SaveTokens = true` is set in your OIDC configuration so tokens are stored in the session.
- Both endpoints use `.RequireAuthorization()` to ensure only authenticated users can access them.
- The `AddUserAccessTokenHttpClient` approach is preferred as it's less error-prone — you can't forget to attach the token.
