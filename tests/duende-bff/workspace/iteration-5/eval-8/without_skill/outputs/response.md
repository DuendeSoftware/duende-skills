# Calling a remote API with the logged-in user's token

You can do this two ways. Both put the HTTP call inside your own BFF endpoint handler, protect the endpoint as a BFF API, and rely on Duende.AccessTokenManagement to refresh the access token automatically — so you never return the token to the browser.

## Pattern 1 — Named HttpClient that attaches the user token

Register a named client and add the user-access-token handler to it. The handler pulls the current user's token from the session and attaches it as a Bearer header on every request, refreshing it when it's expired:

```csharp
using Duende.AccessTokenManagement.OpenIdConnect;

builder.Services.AddHttpClient("remoteApi", client =>
    {
        client.BaseAddress = new Uri("https://remote-service/");
    })
    .AddUserAccessTokenHandler();   // auto-attaches + refreshes the user token

app.MapGet("/api/data", async (IHttpClientFactory factory) =>
{
    var client = factory.CreateClient("remoteApi");   // token attached automatically
    var body = await client.GetStringAsync("data");
    return Results.Text(body);                          // return data, not the token
})
.RequireAuthorization()
.AsBffApiEndpoint();
```

## Pattern 2 — Manual `GetUserAccessTokenAsync`

If you want to make the call yourself, get the token explicitly. `GetUserAccessTokenAsync` returns a valid token, refreshing it behind the scenes if the current one has expired:

```csharp
using Duende.AccessTokenManagement.OpenIdConnect;

app.MapGet("/api/data-manual", async (HttpContext ctx, IHttpClientFactory factory) =>
{
    var token = await ctx.GetUserAccessTokenAsync();   // refreshed automatically if needed

    var client = factory.CreateClient();
    client.DefaultRequestHeaders.Authorization =
        new System.Net.Http.Headers.AuthenticationHeaderValue("Bearer", token.AccessToken);

    var response = await client.GetAsync("https://remote-service/data");
    return Results.Text(await response.Content.ReadAsStringAsync());
})
.RequireAuthorization()
.AsBffApiEndpoint();
```

## Things to keep in mind

- **Protect both endpoints** with `.AsBffApiEndpoint()` so the BFF anti-forgery check applies — these are browser-facing API calls.
- **Automatic refresh:** both patterns go through AccessTokenManagement, which uses the stored refresh token to renew the access token when it expires. You don't write any refresh logic.
- **Never send the token to the client.** Return the *data* from the remote call. Returning the raw access token in the response would leak it into the browser and defeat the point of the BFF.
