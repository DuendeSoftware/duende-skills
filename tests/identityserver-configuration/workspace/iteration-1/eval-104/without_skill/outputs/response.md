# Custom Identity Resource

```csharp
builder.Services.AddIdentityServer()
    .AddInMemoryIdentityResources(new[]
    {
        new IdentityResources.OpenId(),
        new IdentityResources.Profile(),
        new IdentityResource("employee_info", new[] { "employee_id", "department", "hire_date" })
    })
    .AddInMemoryClients(new[]
    {
        new Client
        {
            ClientId = "hr-app",
            AllowedGrantTypes = GrantTypes.Code,
            ClientSecrets = { new Secret("secret".Sha256()) },
            RedirectUris = { "https://hr.example.com/signin-oidc" },
            AllowedScopes = { "openid", "profile", "employee_info" }
        }
    });
```

This defines a custom identity resource that returns the three employee claims when the `employee_info` scope is requested.
