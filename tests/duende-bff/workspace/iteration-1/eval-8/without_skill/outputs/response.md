# Making Authenticated HTTP Calls from BFF Endpoints

## Named HttpClient

```csharp
builder.Services.AddHttpClient("remoteApi", client =>
{
    client.BaseAddress = new Uri("https://remote-service.internal/");
});

app.MapGet("/api/reports", async (HttpContext ctx, IHttpClientFactory factory) =>
{
    var token = await ctx.GetTokenAsync("access_token");
    var client = factory.CreateClient("remoteApi");
    client.DefaultRequestHeaders.Authorization =
        new AuthenticationHeaderValue("Bearer", token);

    var response = await client.GetAsync("reports");
    return Results.Text(await response.Content.ReadAsStringAsync());
}).RequireAuthorization();
```

## Manual Approach

```csharp
app.MapGet("/api/dashboard", async (HttpContext ctx, IHttpClientFactory factory) =>
{
    var token = await ctx.GetTokenAsync("access_token");
    var client = factory.CreateClient();
    client.DefaultRequestHeaders.Authorization =
        new AuthenticationHeaderValue("Bearer", token);

    var response = await client.GetAsync("https://remote-service.internal/dashboard");
    return Results.Text(await response.Content.ReadAsStringAsync());
}).RequireAuthorization();
```

Use `GetTokenAsync("access_token")` to retrieve the access token from the authentication session and attach it to outgoing requests.
