# Calling Two APIs: User Token + Client Credentials

You can use `IHttpClientFactory` with Duende.AccessTokenManagement to register two separate HTTP clients — one for the user's token and one for client credentials.

## Program.cs

```csharp
var builder = WebApplication.CreateBuilder(args);

builder.Services.AddAuthentication(options =>
    {
        options.DefaultScheme = "cookie";
        options.DefaultChallengeScheme = "oidc";
    })
    .AddCookie("cookie")
    .AddOpenIdConnect("oidc", options =>
    {
        options.Authority = "https://sts.example.com";
        options.ClientId = "webapp";
        options.ClientSecret = "secret";
        options.ResponseType = "code";
        options.Scope.Add("openid");
        options.Scope.Add("profile");
        options.Scope.Add("offline_access");
        options.SaveTokens = true;
    });

// Register user token management
builder.Services.AddAccessTokenManagement();

// HTTP client for invoice API - uses the user's token
builder.Services.AddHttpClient("invoices", client =>
{
    client.BaseAddress = new Uri("https://api.example.com/invoices/");
}).AddUserAccessTokenHandler();

// HTTP client for master data API - uses client credentials
builder.Services.AddClientCredentialsTokenManagement()
    .AddClient("masterdata-client", client =>
    {
        client.TokenEndpoint = "https://sts.example.com/connect/token";
        client.ClientId = "webapp";
        client.ClientSecret = "secret";
        client.Scope = "masterdata";
    });

builder.Services.AddHttpClient("masterdata", client =>
{
    client.BaseAddress = new Uri("https://api.example.com/masterdata/");
}).AddClientCredentialsTokenHandler("masterdata-client");

var app = builder.Build();

app.UseAuthentication();
app.UseAuthorization();

app.MapGet("/invoices", async (IHttpClientFactory factory) =>
{
    var client = factory.CreateClient("invoices");
    var response = await client.GetAsync("list");
    return Results.Ok(await response.Content.ReadAsStringAsync());
}).RequireAuthorization();

app.MapGet("/masterdata", async (IHttpClientFactory factory) =>
{
    var client = factory.CreateClient("masterdata");
    var response = await client.GetAsync("countries");
    return Results.Ok(await response.Content.ReadAsStringAsync());
});

app.Run();
```

## Explanation

- The `"invoices"` client uses `AddUserAccessTokenHandler()` to automatically attach the logged-in user's access token.
- The `"masterdata"` client uses `AddClientCredentialsTokenHandler()` to attach a machine-to-machine token.
- Both clients have distinct names and base addresses so you can call `factory.CreateClient("invoices")` or `factory.CreateClient("masterdata")` without manual token management.
