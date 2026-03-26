# Multi-Tenant Token Request Customization with Duende.AccessTokenManagement v4

In a multi-tenant SaaS app where each tenant has different API resources and scopes, you can use `ITokenRequestCustomizer` to dynamically modify token request parameters based on which tenant's API you're calling.

## ITokenRequestCustomizer Implementation

```csharp
public class TenantTokenRequestCustomizer : ITokenRequestCustomizer
{
    private readonly ITenantResolver _tenantResolver;
    private readonly ITenantConfigStore _tenantConfigStore;

    public TenantTokenRequestCustomizer(
        ITenantResolver tenantResolver,
        ITenantConfigStore tenantConfigStore)
    {
        _tenantResolver = tenantResolver;
        _tenantConfigStore = tenantConfigStore;
    }

    public async Task<TokenRequestParameters> Customize(
        HttpRequestMessage httpRequest,
        TokenRequestParameters baseParameters,
        CancellationToken cancellationToken)
    {
        var tenantId = await _tenantResolver.GetTenantIdAsync(httpRequest, cancellationToken);
        var tenantConfig = await _tenantConfigStore.GetConfigurationAsync(tenantId, cancellationToken);

        // ✅ Use 'with' expression to create a modified copy — do not mutate baseParameters
        return baseParameters with
        {
            Resource = Resource.Parse(tenantConfig.ApiResource),
            Scope = Scope.Parse(tenantConfig.RequiredScopes),
        };
    }
}
```

### Key Points

1. **`ITokenRequestCustomizer` interface** — The `Customize` method receives the outgoing `HttpRequestMessage`, the base `TokenRequestParameters`, and a `CancellationToken`.

2. **`with` expression** — Use the C# record `with` expression to create a modified copy of `baseParameters`. Do **not** mutate the original — it may be shared across requests.

3. **Per-request customization** — The customizer runs on every outgoing HTTP request, so you can inspect the request URL, headers, or other properties to determine the tenant.

## Registration

Pass the customizer instance directly to the `Add*Handler` methods:

```csharp
var builder = WebApplication.CreateBuilder(args);

// Register tenant services
builder.Services.AddSingleton<ITenantResolver, HeaderTenantResolver>();
builder.Services.AddSingleton<ITenantConfigStore, DatabaseTenantConfigStore>();

// Build the customizer
var sp = builder.Services.BuildServiceProvider();
var customizer = new TenantTokenRequestCustomizer(
    sp.GetRequiredService<ITenantResolver>(),
    sp.GetRequiredService<ITenantConfigStore>());

// Client credentials setup
builder.Services.AddClientCredentialsTokenManagement()
    .AddClient("api.client", client =>
    {
        client.TokenEndpoint = new Uri("https://sts.example.com/connect/token");
        client.ClientId = ClientId.Parse("saas-app");
        client.ClientSecret = ClientSecret.Parse("secret");
        // Base scope — customizer will override per tenant
        client.Scope = Scope.Parse("api.base");
    });

// Register HTTP client with customizer for client credentials
builder.Services.AddHttpClient("tenant-api")
    .AddClientCredentialsTokenHandler(customizer,
        ClientCredentialsClientName.Parse("api.client"));

// Or for user access tokens:
builder.Services.AddHttpClient("user-tenant-api")
    .AddUserAccessTokenHandler(customizer);
```

## How It Works

1. When an HTTP request is made through the registered client, the token handler intercepts it.
2. Before requesting a token, it calls `Customize()` with the outgoing request and base parameters.
3. The customizer resolves the tenant (e.g., from a request header, URL segment, or ambient context).
4. It creates a modified copy of the parameters using `with`, setting tenant-specific `Resource` and `Scope`.
5. The modified parameters are used for the token request, and the resulting token is cached with a cache key that includes the scope and resource, so different tenants get separate cached tokens.

## Tenant Resolver Example

```csharp
public class HeaderTenantResolver : ITenantResolver
{
    public Task<string> GetTenantIdAsync(
        HttpRequestMessage request,
        CancellationToken cancellationToken)
    {
        if (request.Headers.TryGetValues("X-Tenant-Id", out var values))
        {
            return Task.FromResult(values.First());
        }
        throw new InvalidOperationException("No tenant ID found in request headers");
    }
}
```
