# Adding a Custom Identity Resource

To add custom claims to your identity tokens, you can define custom scopes and map them to the claims you want to include.

## Configuration

```csharp
var builder = WebApplication.CreateBuilder(args);

builder.Services.AddIdentityServer(options =>
{
    options.Events.RaiseErrorEvents = true;
    options.Events.RaiseInformationEvents = true;
})
    .AddInMemoryIdentityResources(new[]
    {
        new IdentityResources.OpenId(),
        new IdentityResources.Profile(),
        new IdentityResource
        {
            Name = "employee_info",
            DisplayName = "Employee Information",
            UserClaims = { "employee_id", "department", "hire_date" }
        }
    })
    .AddInMemoryClients(new[]
    {
        new Client
        {
            ClientId = "webapp",
            AllowedGrantTypes = GrantTypes.Code,
            ClientSecrets = { new Secret("secret".Sha256()) },
            RedirectUris = { "https://app.example.com/signin-oidc" },
            AllowedScopes = { "openid", "profile", "employee_info" }
        }
    });

var app = builder.Build();
app.UseAuthentication();
app.UseAuthorization();
app.Run();
```

## Explanation

The `IdentityResource` class lets you define a named group of claims. When a client requests the `employee_info` scope, the identity token will include the `employee_id`, `department`, and `hire_date` claims.

The client must list `employee_info` in its `AllowedScopes` to be permitted to request this scope. Make sure to also include the standard `openid` scope which is required by OpenID Connect.

Your user store needs to provide these claim values for each authenticated user.
