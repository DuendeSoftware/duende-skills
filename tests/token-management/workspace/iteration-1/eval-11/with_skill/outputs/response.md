# Multi-Tenant Token Request Customization

In Duende.AccessTokenManagement v4, `ITokenRequestCustomizer` lets you dynamically modify token request parameters per outgoing HTTP request. This is ideal for multi-tenant SaaS apps where different tenants require different API resources or scopes.

## ITokenRequestCustomizer Implementation

```csharp
using Duende.AccessTokenManagement;

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
        // Resolve tenant from the outgoing HTTP request (e.g., from a custom header or URL pattern)
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

## Registration

Pass the customizer instance to the `Add*Handler` registration methods:

```csharp
var builder = WebApplication.CreateBuilder(args);

// ── Authentication and token management ──
builder.Services.AddAuthentication(options =>
    {
        options.DefaultScheme = "cookie";
        options.DefaultChallengeScheme = "oidc";
    })
    .AddCookie("cookie")
    .AddOpenIdConnect("oidc", options =>
    {
        options.Authority = "https://sts.example.com";
        options.ClientId = "webapp";
        options.ClientSecret = "secret";
        options.ResponseType = "code";
        options.SaveTokens = true;
        options.Scope.Add("openid");
        options.Scope.Add("offline_access");
    });

builder.Services.AddOpenIdConnectAccessTokenManagement();

// ── Register tenant services ──
builder.Services.AddSingleton<ITenantResolver, HeaderBasedTenantResolver>();
builder.Services.AddSingleton<ITenantConfigStore, DatabaseTenantConfigStore>();

// ── Build the customizer ──
var serviceProvider = builder.Services.BuildServiceProvider();
var customizer = new TenantTokenRequestCustomizer(
    serviceProvider.GetRequiredService<ITenantResolver>(),
    serviceProvider.GetRequiredService<ITenantConfigStore>());

// ── Client credentials client with customizer ──
builder.Services.AddClientCredentialsTokenManagement()
    .AddClient("api-client", client =>
    {
        client.TokenEndpoint = new Uri("https://sts.example.com/connect/token");
        client.ClientId = ClientId.Parse("webapp");
        client.ClientSecret = ClientSecret.Parse("secret");
    });

builder.Services.AddHttpClient("tenant-api", client =>
{
    client.BaseAddress = new Uri("https://api.example.com/");
})
.AddClientCredentialsTokenHandler(customizer,
    ClientCredentialsClientName.Parse("api-client"));

// ── User access token client with customizer ──
builder.Services.AddHttpClient("user-tenant-api", client =>
{
    client.BaseAddress = new Uri("https://api.example.com/");
})
.AddUserAccessTokenHandler(customizer);

var app = builder.Build();

app.UseAuthentication();
app.UseAuthorization();

app.MapGet("/tenant-data", async (IHttpClientFactory factory, CancellationToken ct) =>
{
    // The customizer resolves the tenant and modifies the token request
    // with the correct Resource and Scope automatically
    var client = factory.CreateClient("tenant-api");
    var response = await client.GetAsync("data", ct);
    return Results.Ok(await response.Content.ReadAsStringAsync(ct));
});

app.Run();
```

## How It Works

1. **`ITokenRequestCustomizer`** — The interface has a single `Customize` method that receives the outgoing `HttpRequestMessage`, the base `TokenRequestParameters`, and a `CancellationToken`. It returns a (potentially modified) `TokenRequestParameters`.

2. **`with` expression** — Use `baseParameters with { ... }` to create a new copy with modified properties. Never mutate the original `baseParameters` as it may be shared.

3. **Registration** — Pass the customizer instance directly to `AddClientCredentialsTokenHandler(customizer, clientName)` or `AddUserAccessTokenHandler(customizer)`. The customizer is invoked before every token acquisition, allowing per-request tenant-specific scopes and resources.

4. **Tenant resolution** — The `HttpRequestMessage` gives the customizer access to the outgoing request (URL, headers, etc.), so you can determine the tenant from the request context without relying on `HttpContext`.
