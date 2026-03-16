# Multi-Tenant Token Customization

For a multi-tenant app where each tenant needs different API scopes/resources, you can customize token requests dynamically.

## Custom Token Request Middleware

```csharp
public class TenantTokenCustomizer
{
    private readonly ITenantResolver _tenantResolver;

    public TenantTokenCustomizer(ITenantResolver tenantResolver)
    {
        _tenantResolver = tenantResolver;
    }

    public async Task<TokenRequestParameters> CustomizeAsync(
        HttpContext httpContext, 
        TokenRequestParameters parameters)
    {
        var tenantId = await _tenantResolver.ResolveAsync(httpContext);
        var tenantConfig = await GetTenantConfig(tenantId);

        return new TokenRequestParameters
        {
            Scope = tenantConfig.RequiredScopes,
            Resource = tenantConfig.ApiResource,
        };
    }
}
```

## Registration

```csharp
var builder = WebApplication.CreateBuilder(args);

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
    });

builder.Services.AddAccessTokenManagement();
builder.Services.AddSingleton<ITenantResolver, HeaderTenantResolver>();

builder.Services.AddHttpClient("tenant-api", client =>
{
    client.BaseAddress = new Uri("https://api.example.com/");
}).AddUserAccessTokenHandler();

var app = builder.Build();
app.Run();
```

## Explanation

- Create a customizer class that resolves the tenant from the request context
- Modify the token request parameters (scope, resource) based on the tenant configuration
- Register the HTTP client with appropriate token handler
- Each outgoing request will have tenant-specific token parameters
