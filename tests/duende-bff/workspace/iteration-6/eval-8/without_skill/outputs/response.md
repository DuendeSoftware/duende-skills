# Calling a remote API manually from a local endpoint

## 1. Named HttpClient with token management

```csharp
builder.Services.AddUserAccessTokenHttpClient("catalog", configureClient: c =>
{
    c.BaseAddress = new Uri("https://api.example.com/");
});

app.MapGet("/api/data", async (IHttpClientFactory factory) =>
{
    var client = factory.CreateClient("catalog");
    var res = await client.GetAsync("data");
    return Results.Content(await res.Content.ReadAsStringAsync(), "application/json");
})
.RequireAuthorization()
.AsBffApiEndpoint();
```
(`AddUserAccessTokenHttpClient` comes from Duende.AccessTokenManagement; refresh is automatic.)

## 2. Manual token

```csharp
app.MapGet("/api/data2", async (HttpContext ctx, IHttpClientFactory f) =>
{
    var token = await ctx.GetUserAccessTokenAsync();
    if (token.IsError) return Results.Unauthorized();

    var client = f.CreateClient();
    client.SetBearerToken(token.AccessToken!);
    var json = await client.GetStringAsync("https://api.example.com/data");
    return Results.Content(json, "application/json");
})
.RequireAuthorization()
.AsBffApiEndpoint();
```
Requires `offline_access` for refresh and `AddBff()` + `UseBff()`.
