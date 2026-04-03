# User Token Management for ASP.NET Core Web App

Here's how to set up an ASP.NET Core web app with OIDC authentication and a named HTTP client that attaches the user's access token automatically.

## `Program.cs`

```csharp
var builder = WebApplication.CreateBuilder(args);

// Configure authentication
builder.Services.AddAuthentication(options =>
{
    options.DefaultScheme = "Cookies";
    options.DefaultChallengeScheme = "OpenIdConnect";
})
.AddCookie("Cookies")
.AddOpenIdConnect("OpenIdConnect", options =>
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

// Add token management
builder.Services.AddOpenIdConnectAccessTokenManagement();

// Register HTTP client for invoice API
builder.Services.AddHttpClient("invoices", client =>
{
    client.BaseAddress = new Uri("https://api.example.com/invoices/");
});

var app = builder.Build();

app.UseAuthentication();
app.UseAuthorization();

app.MapGet("/call-api", async (IHttpClientFactory httpClientFactory, HttpContext httpContext, CancellationToken ct) =>
{
    // Get the access token from the authentication properties
    var token = await httpContext.GetTokenAsync("access_token");
    
    var client = httpClientFactory.CreateClient("invoices");
    client.DefaultRequestHeaders.Authorization = 
        new System.Net.Http.Headers.AuthenticationHeaderValue("Bearer", token);
    
    var response = await client.GetAsync("list", ct);
    var content = await response.Content.ReadAsStringAsync(ct);
    return Results.Ok(content);
}).RequireAuthorization();

app.Run();
```

## Notes

- `SaveTokens = true` ensures the tokens are stored in the authentication properties so they can be retrieved later.
- `offline_access` scope requests a refresh token from the identity provider.
- `AddOpenIdConnectAccessTokenManagement()` provides token management services.
- The HTTP client is configured to call the invoices API, and the access token is manually attached from the authentication properties.
