# Adding a local endpoint and a remote proxy with Duende BFF

You want two kinds of API surface behind the BFF:

- A **local** `GET /api/orders` that runs in-process and requires the user to be authenticated.
- A **remote** proxy so `/api/catalog/*` is forwarded to `https://catalog-service.internal/api`, attaching the logged-in user's access token.

Duende BFF supports both. Register the remote API services, then map the endpoints.

```csharp
using Duende.Bff;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddBff()
    .AddRemoteApis();   // enables the remote/proxy endpoints

// ... your AddAuthentication()/AddOpenIdConnect() setup ...

builder.Services.AddAuthorization();

var app = builder.Build();

app.UseAuthentication();
app.UseBff();
app.UseAuthorization();

// Local endpoint — order data, only for authenticated users
app.MapGet("/api/orders", () => new[]
    {
        new { Id = 1, Total = 42.00m },
        new { Id = 2, Total = 17.50m }
    })
    .RequireAuthorization()
    .AsBffApiEndpoint();   // adds BFF CSRF protection

// Remote proxy — forward /api/catalog to the catalog service with the user's token
app.MapRemoteBffApiEndpoint("/api/catalog", new Uri("https://catalog-service.internal/api"))
    .RequireAccessToken(TokenType.User);

app.Run();
```

## Notes

- **`AsBffApiEndpoint()`** marks the local endpoint as a BFF API so it participates in anti-forgery (the browser must send the BFF anti-forgery header) and gets the correct 401 behaviour instead of an HTML redirect.
- **`RequireAuthorization()`** blocks anonymous callers from `/api/orders`.
- **`MapRemoteBffApiEndpoint`** sets up the reverse-proxy passthrough. `RequireAccessToken(TokenType.User)` makes BFF look up the current user's access token and send it as a Bearer header to the catalog service, so the downstream API sees the user's identity. Anonymous users are challenged.
- The proxy covers `/api/catalog` and everything beneath it.

From the front-end, call these through `fetch` and include the anti-forgery header the BFF expects so the requests aren't rejected as CSRF.
