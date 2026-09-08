# Per-Tenant Token Requests in a Multi-Tenant App

You want the scope (and API resource) sent when acquiring a token to depend on which tenant's API you're about to call. The cleanest way is to resolve the tenant first, then request a token with tenant-specific parameters.

## Option A: Resolve the tenant and override the request parameters

`GetAccessTokenAsync` accepts a parameters object where you can set the scope/resource per request, so you can vary them by tenant:

```csharp
public class TenantApiCaller
{
    private readonly IUserTokenManagementService _tokens; // or the client-credentials manager
    private readonly ITenantResolver _tenantResolver;
    private readonly ITenantConfigStore _configStore;
    private readonly IHttpClientFactory _factory;

    public TenantApiCaller(
        IUserTokenManagementService tokens,
        ITenantResolver tenantResolver,
        ITenantConfigStore configStore,
        IHttpClientFactory factory)
    {
        _tokens = tokens;
        _tenantResolver = tenantResolver;
        _configStore = configStore;
        _factory = factory;
    }

    public async Task<HttpResponseMessage> CallAsync(ClaimsPrincipal user, CancellationToken ct)
    {
        var tenant = await _tenantResolver.GetCurrentTenantAsync(ct);
        var cfg = await _configStore.GetConfigurationAsync(tenant, ct);

        // Per-tenant scope / resource for this token request
        var parameters = new UserTokenRequestParameters
        {
            Scope = cfg.RequiredScopes,
            Resource = cfg.ApiResource
        };

        var token = await _tokens.GetAccessTokenAsync(user, parameters, ct);

        var client = _factory.CreateClient();
        client.SetBearerToken(token.AccessToken);
        return await client.GetAsync(cfg.ApiBaseUrl, ct);
    }
}
```

## Option B: A delegating handler that injects tenant scope

If you want it transparent to callers, add a `DelegatingHandler` to your typed/named `HttpClient` that resolves the tenant from the outgoing request and requests a token with the right scope before forwarding the call:

```csharp
public class TenantTokenHandler : DelegatingHandler
{
    private readonly ITenantResolver _tenantResolver;
    private readonly ITenantConfigStore _configStore;
    private readonly IUserTokenManagementService _tokens;
    private readonly IHttpContextAccessor _http;

    // ctor omitted for brevity

    protected override async Task<HttpResponseMessage> SendAsync(
        HttpRequestMessage request, CancellationToken ct)
    {
        var tenant = await _tenantResolver.GetTenantForRequestAsync(request, ct);
        var cfg = await _configStore.GetConfigurationAsync(tenant, ct);

        var token = await _tokens.GetAccessTokenAsync(
            _http.HttpContext!.User,
            new UserTokenRequestParameters { Scope = cfg.RequiredScopes, Resource = cfg.ApiResource },
            ct);

        request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", token.AccessToken);
        return await base.SendAsync(request, ct);
    }
}
```

Register it with:

```csharp
builder.Services.AddTransient<TenantTokenHandler>();
builder.Services.AddHttpClient("tenant-api").AddHttpMessageHandler<TenantTokenHandler>();
```

## Option C: Per-tenant named clients

If the set of tenants is small and static, register a distinct named client per tenant, each configured with that tenant's scope/resource.

---

**Recommendation:** Option A/B keeps things dynamic. Whichever you choose, make sure the token cache differentiates tenants (different scope/resource) so one tenant's token isn't reused for another. Check the Duende docs for any built-in per-request customization hook that may let the library handle this for you rather than a custom handler.
