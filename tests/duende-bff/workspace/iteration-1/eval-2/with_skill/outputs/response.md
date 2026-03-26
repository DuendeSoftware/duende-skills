# Local and Remote BFF API Endpoints

## Updated Program.cs

```csharp
var builder = WebApplication.CreateBuilder(args);

builder.Services.AddBff()
    .ConfigureOpenIdConnect(options =>
    {
        options.Authority = "https://idp.example.com";
        options.ClientId = "spa-bff-client";
        options.ClientSecret = "secret";
        options.ResponseType = "code";
        options.SaveTokens = true;
        options.Scope.Add("openid");
        options.Scope.Add("profile");
        options.Scope.Add("offline_access");
    })
    .AddRemoteApis();  // Required for MapRemoteBffApiEndpoint

builder.Services.AddAuthorization();

var app = builder.Build();

app.UseRouting();
app.UseAuthentication();
app.UseBff();
app.UseAuthorization();

// Local API endpoint — runs in the BFF process
app.MapGet("/api/orders", (HttpContext ctx) =>
{
    var orders = new[]
    {
        new { Id = 1, Product = "Widget", Quantity = 5 },
        new { Id = 2, Product = "Gadget", Quantity = 2 },
    };
    return Results.Ok(orders);
})
.RequireAuthorization()    // Requires authenticated user
.AsBffApiEndpoint();       // Enforces X-CSRF header

// Remote API proxy — forwards to catalog service with user's access token
app.MapRemoteBffApiEndpoint("/api/catalog", new Uri("https://catalog-service.internal/api"))
    .WithAccessToken(RequiredTokenType.User);  // Attaches user's access token

app.Run();
```

## How It Works

- **Local endpoint `/api/orders`**: Runs in the BFF process. `.RequireAuthorization()` ensures the user is authenticated. `.AsBffApiEndpoint()` enforces the `X-CSRF: 1` header to prevent CSRF attacks.
- **Remote endpoint `/api/catalog`**: Uses `MapRemoteBffApiEndpoint` to proxy requests to the catalog service. The BFF automatically exchanges the session cookie for the user's access token and forwards it.
- **`.AddRemoteApis()`**: Must be called on the BFF builder to enable remote API endpoint support. Without it, `MapRemoteBffApiEndpoint` won't work.
- **`.WithAccessToken(RequiredTokenType.User)`**: Attaches the logged-in user's access token to the forwarded request. If the user isn't authenticated, a 401 challenge is returned.
