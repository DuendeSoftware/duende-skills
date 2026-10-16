# Validating reference tokens via introspection

Opaque reference tokens can't be validated locally; the API calls IdentityServer's introspection endpoint. Use the introspection handler:

```bash
dotnet add package Duende.AspNetCore.Authentication.OAuth2Introspection
```

```csharp
var builder = WebApplication.CreateBuilder(args);
builder.Services.AddControllers();

builder.Services.AddAuthentication("token")
    .AddOAuth2Introspection("token", options =>
    {
        options.Authority = "https://auth.mycompany.com";
        options.ClientId = "invoicing";               // ApiResource name
        options.ClientSecret = "invoicing_secret";    // ApiResource secret – keep in a secret store
    });

builder.Services.AddAuthorization(o =>
    o.FallbackPolicy = new AuthorizationPolicyBuilder().RequireAuthenticatedUser().Build());

var app = builder.Build();
app.UseRouting();
app.UseAuthentication();
app.UseAuthorization();
app.MapControllers();
app.MapGet("/data", () => Results.Ok(new { message = "Protected" }));
app.Run();
```

## IdentityServer side
`ClientId`/`ClientSecret` are the **ApiResource** name and secret. The resource must have an `ApiSecrets` entry or introspection fails with 401:

```csharp
// ❌ no ApiSecrets -> introspection returns 401
new ApiResource("invoicing") { Scopes = { "invoicing.read" } };

// ✅
new ApiResource("invoicing")
{
    ApiSecrets = { new Secret("invoicing_secret".Sha256()) },
    Scopes = { "invoicing.read" }
};
```

## Troubleshooting
- `active: false` from introspection: check the secret matches and the scopes are associated with the ApiResource.
- Reference tokens are revocable immediately, but each request depends on IdentityServer being available.
- Add scope policies (`RequireClaim("scope", "invoicing.read")`) for authorization.
