# Validating reference tokens with introspection

Use the OAuth 2.0 introspection handler from Duende (IdentityModel.AspNetCore.OAuth2Introspection):

```
dotnet add package IdentityModel.AspNetCore.OAuth2Introspection
```

```csharp
using IdentityModel.AspNetCore.OAuth2Introspection;

var builder = WebApplication.CreateBuilder(args);
builder.Services.AddControllers();

builder.Services
    .AddAuthentication(OAuth2IntrospectionDefaults.AuthenticationScheme)
    .AddOAuth2Introspection(options =>
    {
        options.Authority = "https://auth.mycompany.com";
        options.ClientId = "invoicing";
        options.ClientSecret = "invoicing_secret";   // load from config/secret store, not source
        options.CacheDuration = TimeSpan.FromMinutes(5);
        options.EnableCaching = true;
    });

builder.Services.AddDistributedMemoryCache(); // needed for caching introspection results

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

## Notes
- The API resource must have an **ApiSecret** (`invoicing_secret`, stored hashed) in IdentityServer; the API authenticates to the introspection endpoint with it.
- The handler discovers the introspection endpoint from `/.well-known/openid-configuration`.
- Caching reduces round trips, but revoked tokens remain valid until cache expiry; pick a short duration.
- Store the secret in user-secrets, environment variables, or Key Vault.
- Reference tokens must be sent as `Authorization: Bearer <token>`.
