To achieve audience isolation between your `catalog-api` and `orders-api` microservices, you need to use both **API Scopes** (for permissions) and **API Resources** (for audience boundaries). The `ApiResource` controls the `aud` claim in access tokens, ensuring a token issued for one API cannot be used at another.

Here's the full configuration:

```csharp
var builder = WebApplication.CreateBuilder(args);

var idsvrBuilder = builder.Services.AddIdentityServer(options =>
{
    options.Events.RaiseErrorEvents = true;
    options.Events.RaiseInformationEvents = true;
    options.Events.RaiseFailureEvents = true;
    options.Events.RaiseSuccessEvents = true;
})
    .AddInMemoryApiScopes(new List<ApiScope>
    {
        new ApiScope("read", "Read Access"),
        new ApiScope("write", "Write Access")
    })
    .AddInMemoryApiResources(new List<ApiResource>
    {
        new ApiResource("catalog-api", "Product Catalog API")
        {
            Scopes = { "read", "write" }
        },
        new ApiResource("orders-api", "Order Management API")
        {
            Scopes = { "read" }
        }
    })
    .AddInMemoryClients(Array.Empty<Client>());

var app = builder.Build();

app.UseIdentityServer();
app.UseAuthorization();

app.MapGet("/", () => "IdentityServer is running");

app.Run();
```

### How It Works

1. **`ApiScope`** defines the permissions (`read` and `write`). These are the values clients request via the `scope` parameter.

2. **`ApiResource`** defines the logical API boundaries:
   - `catalog-api` owns both `read` and `write` scopes
   - `orders-api` owns only the `read` scope

3. **Audience isolation** — When a client requests a token targeting `catalog-api`, IdentityServer includes `"aud": "catalog-api"` in the access token. The `orders-api` validates that the `aud` claim matches its own name and rejects tokens issued for `catalog-api`, even if they contain the `read` scope.

4. Clients specify which resource they want via the `resource` parameter (RFC 8707) in the token request, and IdentityServer issues a token scoped to that audience.

### Key Distinction

- **`ApiScope` alone** — Sufficient for simple single-API setups. No audience claim isolation.
- **`ApiResource` + `ApiScope`** — Required when multiple APIs share scope names and you need token isolation between them. The `ApiResource` name becomes the `aud` claim.
