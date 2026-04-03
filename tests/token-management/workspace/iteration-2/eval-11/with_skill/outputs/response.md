# Dynamic Token Request Customization for Multi-Tenant SaaS

In Duende.AccessTokenManagement v4, the `ITokenRequestCustomizer` interface lets you dynamically modify token request parameters per outgoing HTTP request. This is exactly what you need for multi-tenant scenarios.

## Implement ITokenRequestCustomizer

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
        // Resolve which tenant this outgoing request targets
        var tenantId = await _tenantResolver.GetTenantIdAsync(httpRequest, cancellationToken);
        var tenantConfig = await _tenantConfigStore.GetConfigurationAsync(tenantId, cancellationToken);

        // Use 'with' expression to create a modified copy — do NOT mutate baseParameters
        return baseParameters with
        {
            Resource = Resource.Parse(tenantConfig.ApiResource),
            Scope = Scope.Parse(tenantConfig.RequiredScopes),
        };
    }
}
```

The `Customize` method receives:
- `HttpRequestMessage httpRequest` — the outgoing HTTP request, so you can inspect the URL, headers, etc. to determine the tenant
- `TokenRequestParameters baseParameters` — the base parameters configured on the client
- `CancellationToken cancellationToken`

**Important**: Use the `with` expression to return a modified copy of `baseParameters`. Do not mutate it directly.

## Register the Customizer

Pass the customizer instance to `AddClientCredentialsTokenHandler` or `AddUserAccessTokenHandler`:

```csharp
var builder = WebApplication.CreateBuilder(args);

// Register your tenant services
builder.Services.AddSingleton<ITenantResolver, HeaderBasedTenantResolver>();
builder.Services.AddSingleton<ITenantConfigStore, DatabaseTenantConfigStore>();

// Register client credentials
builder.Services.AddClientCredentialsTokenManagement()
    .AddClient("api-client", client =>
    {
        client.TokenEndpoint = new Uri("https://sts.example.com/connect/token");
        client.ClientId = ClientId.Parse("my-saas-app");
        client.ClientSecret = ClientSecret.Parse("secret");
        // Default scope — will be overridden per-tenant by the customizer
        client.Scope = Scope.Parse("api.default");
    });

// Build the customizer (resolve from DI or create directly)
var sp = builder.Services.BuildServiceProvider();
var customizer = new TenantTokenRequestCustomizer(
    sp.GetRequiredService<ITenantResolver>(),
    sp.GetRequiredService<ITenantConfigStore>());

// Client credentials HTTP client with per-tenant customization
builder.Services.AddHttpClient("tenant-api")
    .AddClientCredentialsTokenHandler(
        customizer,
        ClientCredentialsClientName.Parse("api-client"));

// User access token HTTP client with per-tenant customization
builder.Services.AddHttpClient("user-tenant-api")
    .AddUserAccessTokenHandler(customizer);
```

Each outgoing HTTP request through these clients will invoke the customizer, which resolves the tenant and adjusts the `Resource` and `Scope` on the token request accordingly. The token management library caches tokens per unique combination of client name, scope, and resource, so different tenants will get different cached tokens.
