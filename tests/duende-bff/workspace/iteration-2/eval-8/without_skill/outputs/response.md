Here are two approaches for making HTTP calls from a local BFF API endpoint with the user's token:

## Named HttpClient Pattern

```csharp
// Register a typed HTTP client
builder.Services.AddHttpClient("remoteApi", client =>
{
    client.BaseAddress = new Uri("https://remote-service.internal/");
});

// Endpoint
app.MapGet("/api/data", async (HttpContext ctx, IHttpClientFactory factory) =>
{
    var token = await ctx.GetTokenAsync("access_token");
    var client = factory.CreateClient("remoteApi");
    client.DefaultRequestHeaders.Authorization = 
        new AuthenticationHeaderValue("Bearer", token);
    
    var response = await client.GetAsync("data");
    return Results.Text(await response.Content.ReadAsStringAsync());
})
.RequireAuthorization();
```

## Manual Pattern

```csharp
app.MapGet("/api/data-manual", async (HttpContext ctx) =>
{
    var token = await ctx.GetTokenAsync("access_token");
    var client = new HttpClient();
    client.DefaultRequestHeaders.Authorization = 
        new AuthenticationHeaderValue("Bearer", token);
    
    var response = await client.GetAsync("https://remote-service.internal/data");
    return Results.Text(await response.Content.ReadAsStringAsync());
})
.RequireAuthorization();
```

Make sure you have `SaveTokens = true` in your OIDC configuration so the token is available in the authentication properties.
