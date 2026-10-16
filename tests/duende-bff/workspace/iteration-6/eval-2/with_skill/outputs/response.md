# Local + remote API with BFF v4

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
        options.MapInboundClaims = false;
        options.Scope.Clear();
        options.Scope.Add("openid");
        options.Scope.Add("profile");
        options.Scope.Add("offline_access");
    })
    .AddRemoteApis();            // Duende.BFF.Yarp: dotnet add package Duende.BFF.Yarp

builder.Services.AddAuthorization();
var app = builder.Build();

app.UseRouting();
app.UseAuthentication();
app.UseBff();
app.UseAuthorization();

// Local endpoint: authenticated + anti-forgery enforced
app.MapGet("/api/orders", () => Results.Ok(new[] { new { Id = 1, Total = 42.5m } }))
   .RequireAuthorization()
   .AsBffApiEndpoint();

// Remote endpoint: forward user's access token
app.MapRemoteBffApiEndpoint("/api/catalog", new Uri("https://catalog-service.internal/api"))
   .WithAccessToken(RequiredTokenType.User);

app.Run();
```

- `AsBffApiEndpoint()` enforces the `X-CSRF: 1` header and returns 401/403 rather than redirects for the SPA. Without it the local endpoint is CSRF-vulnerable.
- `MapRemoteBffApiEndpoint` enforces anti-forgery itself, strips the browser's `Cookie` header, and attaches the user's token (refreshed automatically via `offline_access`).
- Don't map broad paths like `/` or `/api`; here `/api/catalog` doesn't shadow `/api/orders`.
- SPA calls must include `X-CSRF: 1`:

```js
const orders = await fetch('/api/orders', { headers: { 'X-CSRF': '1' } }).then(r => r.json());
```
