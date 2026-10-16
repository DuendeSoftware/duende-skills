# Calling a remote API from a local BFF endpoint

Requires `AddBff()` with `SaveTokens = true` and `offline_access` so ATM can refresh tokens.

## 1. Named HttpClient (preferred)

```csharp
builder.Services.AddUserAccessTokenHttpClient("apiClient", configureClient: client =>
{
    client.BaseAddress = new Uri("https://remote-service/");
});

app.MapGet("/api/proxy", async (IHttpClientFactory factory) =>
{
    var client = factory.CreateClient("apiClient");   // token attached & refreshed automatically
    var response = await client.GetAsync("data");
    return Results.Text(await response.Content.ReadAsStringAsync(), "application/json");
})
.RequireAuthorization()
.AsBffApiEndpoint();
```

(Typed alternative: `builder.Services.AddHttpClient<RemoteApiClient>(...).AddUserAccessTokenHandler();`)

## 2. Manual GetUserAccessTokenAsync

```csharp
app.MapGet("/api/data", async (HttpContext ctx, IHttpClientFactory factory) =>
{
    var token = await ctx.GetUserAccessTokenAsync();   // refreshes if expired
    var client = factory.CreateClient();
    client.SetBearerToken(token);

    var response = await client.GetAsync("https://remote-service/data");
    return Results.Text(await response.Content.ReadAsStringAsync(), "application/json");
})
.RequireAuthorization()
.AsBffApiEndpoint();
```

Do not return the token itself to the browser — that defeats the BFF pattern. `.AsBffApiEndpoint()` enforces `X-CSRF: 1`.
