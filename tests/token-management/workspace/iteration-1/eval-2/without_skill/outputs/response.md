# User Token Management Setup

```csharp
var builder = WebApplication.CreateBuilder(args);

builder.Services.AddAuthentication(options =>
{
    options.DefaultScheme = "Cookies";
    options.DefaultChallengeScheme = "oidc";
})
.AddCookie("Cookies")
.AddOpenIdConnect("oidc", options =>
{
    options.Authority = "https://sts.example.com";
    options.ClientId = "webapp";
    options.ClientSecret = "secret";
    options.ResponseType = "code";

    options.Scope.Add("openid");
    options.Scope.Add("profile");
    options.Scope.Add("email");
    options.Scope.Add("invoice");
    options.Scope.Add("offline_access");

    options.SaveTokens = true;
});

builder.Services.AddOpenIdConnectAccessTokenManagement();

builder.Services.AddHttpClient("invoices", client =>
{
    client.BaseAddress = new Uri("https://api.example.com/invoices/");
}).AddUserAccessTokenHandler();

var app = builder.Build();
app.UseAuthentication();
app.UseAuthorization();

app.MapGet("/call-api", async (IHttpClientFactory factory, CancellationToken ct) =>
{
    var client = factory.CreateClient("invoices");
    var response = await client.GetAsync("list", ct);
    return Results.Ok(await response.Content.ReadAsStringAsync(ct));
}).RequireAuthorization();

app.Run();
```

This configures cookie + OIDC authentication with token management. The HTTP client automatically attaches the user's access token.
