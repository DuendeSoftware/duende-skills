# Per-tenant token requests with `ITokenRequestCustomizer` (v4)

Implement `ITokenRequestCustomizer`; it's invoked per outgoing HTTP request and returns the token request parameters (resource/scope) for that request. Use a `with` expression: don't mutate `baseParameters`.

```csharp
public class TenantTokenRequestCustomizer(
    ITenantResolver tenantResolver,
    ITenantConfigStore tenantConfigStore) : ITokenRequestCustomizer
{
    public async Task<TokenRequestParameters> Customize(
        HttpRequestMessage httpRequest,
        TokenRequestParameters baseParameters,
        CancellationToken cancellationToken)
    {
        var tenantId = await tenantResolver.GetTenantIdAsync(httpRequest, cancellationToken);
        var tenant = await tenantConfigStore.GetConfigurationAsync(tenantId, cancellationToken);

        // ✅ modified copy
        return baseParameters with
        {
            Resource = Resource.Parse(tenant.ApiResource),
            Scope = Scope.Parse(tenant.RequiredScopes),
        };
    }
}
```

## Registration
Pass the customizer to the handler registration:

```csharp
var customizer = new TenantTokenRequestCustomizer(tenantResolver, tenantConfigStore);

// client credentials
services.AddHttpClient("tenant-api-cc")
    .AddClientCredentialsTokenHandler(customizer, ClientCredentialsClientName.Parse("api-client"));

// user access tokens
services.AddHttpClient("tenant-api-user")
    .AddUserAccessTokenHandler(customizer);
```
(In practice resolve the resolver/store from DI, for example via an `AddHttpMessageHandler` factory or by creating the customizer from `IServiceProvider`.)

## Notes
- The cache key includes scope and resource, so tokens for different tenants are cached separately. If you add custom `TokenRequestParameters` that influence the token, implement `IClientCredentialsCacheKeyGenerator` so keys stay distinct.
- Per-call alternatives: pass `UserTokenRequestParameters { Scope = ..., Resource = ... }` to `IUserTokenManager.GetAccessTokenAsync`, or `TokenRequestParameters` to `IClientCredentialsTokenManager`.
- For total control over token selection, implement `AccessTokenRequestHandler.ITokenRetriever` and register it through `AddHttpMessageHandler` (with `AddDefaultAccessTokenResiliency()`).
- Remember `SaveTokens = true` and `offline_access` for user tokens.
