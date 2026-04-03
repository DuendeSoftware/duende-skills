# Dynamic Token Requests for Multi-Tenant SaaS

For a multi-tenant scenario where each tenant requires different API resources and scopes, you'll need to customize the token request dynamically. Here's how you might approach this with Duende.AccessTokenManagement.

## Approach: Custom DelegatingHandler

You can create a custom `DelegatingHandler` that intercepts outgoing requests, determines the tenant, and requests the appropriate token:

```csharp
public class TenantTokenHandler : DelegatingHandler
{
    private readonly IClientCredentialsTokenManagementService _tokenService;
    private readonly ITenantResolver _tenantResolver;

    public TenantTokenHandler(
        IClientCredentialsTokenManagementService tokenService,
        ITenantResolver tenantResolver)
    {
        _tokenService = tokenService;
        _tenantResolver = tenantResolver;
    }

    protected override async Task<HttpResponseMessage> SendAsync(
        HttpRequestMessage request, CancellationToken cancellationToken)
    {
        var tenantId = _tenantResolver.GetTenantId(request);
        var tenantConfig = GetTenantConfig(tenantId);

        // Request a token with tenant-specific scope
        var token = await _tokenService.GetAccessTokenAsync(
            tenantConfig.ClientName,
            cancellationToken);

        request.SetBearerToken(token.Value);

        return await base.SendAsync(request, cancellationToken);
    }

    private TenantConfig GetTenantConfig(string tenantId)
    {
        // Look up tenant-specific configuration
        return new TenantConfig
        {
            ClientName = $"client-{tenantId}",
            Scope = $"api.{tenantId}"
        };
    }
}
```

## Registration

Register a separate named client for each tenant, or use a single client with per-request overrides:

```csharp
var builder = WebApplication.CreateBuilder(args);

builder.Services.AddDistributedMemoryCache();

// Register one client per tenant
foreach (var tenant in tenants)
{
    builder.Services.AddClientCredentialsTokenManagement()
        .AddClient($"client-{tenant.Id}", client =>
        {
            client.TokenEndpoint = "https://sts.example.com/connect/token";
            client.ClientId = "my-saas-app";
            client.ClientSecret = "secret";
            client.Scope = tenant.RequiredScopes;
        });
}

// Register the HTTP client with the custom handler
builder.Services.AddTransient<TenantTokenHandler>();
builder.Services.AddHttpClient("tenant-api")
    .AddHttpMessageHandler<TenantTokenHandler>();
```

This approach registers a separate client configuration for each tenant. The custom handler resolves the tenant from the request and uses the appropriate client name to get the correctly-scoped token.

An alternative approach is to use `TokenRequestParameters` to override the scope per request when calling `GetAccessTokenAsync` manually. This avoids needing a separate client registration per tenant but requires more manual token management code.
