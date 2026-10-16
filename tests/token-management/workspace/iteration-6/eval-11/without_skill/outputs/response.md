# Per-tenant token requests in v4

Use token request parameters, which can be passed per call and also baked into a client's configuration. Typical approach: register one client per tenant, or one client and pass parameters dynamically.

## Option 1 – per call parameters (user tokens)

```csharp
var token = await tokenManager.GetAccessTokenAsync(user, new UserTokenRequestParameters
{
    Resource = Resource.Parse("urn:tenant-a:api"),
    Scope = Scope.Parse("tenant-a.read"),
    ForceTokenRenewal = false
}, ct);
```

## Option 2 – client credentials, one client per tenant

```csharp
foreach (var t in tenants)
{
    services.AddClientCredentialsTokenManagement()
        .AddClient($"tenant.{t.Id}", c =>
        {
            c.TokenEndpoint = new Uri("https://sts.example.com/connect/token");
            c.ClientId = ClientId.Parse("saas");
            c.ClientSecret = ClientSecret.Parse("...");
            c.Scope = Scope.Parse(t.Scopes);
            c.Resource = Resource.Parse(t.ApiResource);
        });
    services.AddClientCredentialsHttpClient($"tenant-{t.Id}", ClientCredentialsClientName.Parse($"tenant.{t.Id}"),
        h => h.BaseAddress = new Uri(t.ApiUrl));
}
```

## Option 3 – dynamic: custom DelegatingHandler

Write a handler that resolves the tenant from the request and calls `IUserTokenManager` with parameters, then sets the bearer header. Tokens are cached by parameters (scope/resource), so different tenants get separate cache entries.
