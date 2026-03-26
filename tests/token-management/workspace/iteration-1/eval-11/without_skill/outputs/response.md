# Multi-Tenant Token Request Customization

For a multi-tenant SaaS app where each tenant needs different scopes and resources, you can customize token requests dynamically.

## Approach

Duende.AccessTokenManagement supports customizing token requests per-call. You can implement a customizer that modifies token parameters based on the tenant context.

```csharp
public class TenantTokenCustomizer : ITokenRequestCustomizer
{
    private readonly ITenantResolver _tenantResolver;
    private readonly ITenantConfigStore _configStore;

    public TenantTokenCustomizer(ITenantResolver resolver, ITenantConfigStore configStore)
    {
        _tenantResolver = resolver;
        _configStore = configStore;
    }

    public async Task<TokenRequestParameters> Customize(
        HttpRequestMessage httpRequest,
        TokenRequestParameters baseParameters,
        CancellationToken cancellationToken)
    {
        var tenantId = await _tenantResolver.GetTenantIdAsync(httpRequest, cancellationToken);
        var config = await _configStore.GetConfigurationAsync(tenantId, cancellationToken);

        // Create a modified copy with tenant-specific values
        return baseParameters with
        {
            Resource = Resource.Parse(config.ApiResource),
            Scope = Scope.Parse(config.RequiredScopes)
        };
    }
}
```

## Registration

```csharp
builder.Services.AddSingleton<ITenantResolver, HeaderTenantResolver>();
builder.Services.AddSingleton<ITenantConfigStore, DbTenantConfigStore>();

var customizer = new TenantTokenCustomizer(
    tenantResolver, tenantConfigStore);

builder.Services.AddHttpClient("tenant-api")
    .AddClientCredentialsTokenHandler(customizer,
        ClientCredentialsClientName.Parse("api.client"));
```

The customizer is invoked on every outgoing request, allowing you to inspect the request and determine the appropriate tenant-specific token parameters. The library handles caching separate tokens for different scope/resource combinations automatically.
