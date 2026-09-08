# Multi-Tenant Token Requests with `ITokenRequestCustomizer`

In v4, implement `ITokenRequestCustomizer` to modify the token request per outgoing HTTP request. Resolve the tenant from the outgoing `HttpRequestMessage`, look up that tenant's API resource/scopes, and return a **modified copy** of the base parameters using a `with` expression (never mutate the base). Register the customizer on the `Add*Handler` methods.

## The customizer

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
        // Resolve the tenant from the outgoing request (host, header, route, etc.)
        var tenantId = await _tenantResolver.GetTenantIdAsync(httpRequest, cancellationToken);
        var tenantConfig = await _tenantConfigStore.GetConfigurationAsync(tenantId, cancellationToken);

        // ✅ 'with' expression — create a modified copy; do NOT mutate baseParameters
        return baseParameters with
        {
            Resource = Resource.Parse(tenantConfig.ApiResource),
            Scope = Scope.Parse(tenantConfig.RequiredScopes),
        };
    }
}
```

Key points:
- **Signature:** `Customize(HttpRequestMessage httpRequest, TokenRequestParameters baseParameters, CancellationToken cancellationToken)`.
- **Immutability:** `TokenRequestParameters` is a record — use `baseParameters with { ... }` to produce a modified copy per request. Mutating the shared instance would leak one tenant's settings into another's request.
- Set whatever varies per tenant here: `Resource`, `Scope` (and other request parameters).

## Registration — pass the customizer to the `Add*Handler` methods

```csharp
var customizer = new TenantTokenRequestCustomizer(tenantResolver, tenantConfigStore);

// ✅ Client credentials client with the customizer
builder.Services.AddHttpClient("client-credentials-http-client")
    .AddClientCredentialsTokenHandler(customizer,
        ClientCredentialsClientName.Parse("api-client"));

// ✅ Or a user-access-token client with the customizer
builder.Services.AddHttpClient("user-access-http-client")
    .AddUserAccessTokenHandler(customizer);
```

Now, whenever a request goes out through one of these clients, the handler invokes your `Customize` method, resolves the tenant, and requests a token scoped to that tenant's API resource and scopes — cached per distinct scope/resource so tenants don't share tokens.

> If you inject the customizer from DI (so `ITenantResolver` / `ITenantConfigStore` are resolved by the container), register `TenantTokenRequestCustomizer` and resolve it when configuring the handler rather than `new`-ing it up. For custom `TokenRequestParameters`, also implement `IClientCredentialsCacheKeyGenerator` so per-tenant tokens get distinct cache keys.
