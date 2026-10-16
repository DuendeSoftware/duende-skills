# Securing `/connect/dcr` with JWT bearer and a scope check

Never expose the DCR endpoint unauthenticated. `MapDynamicClientRegistration()` returns an endpoint convention builder, so apply a standard ASP.NET Core policy.

```csharp
builder.Services.AddIdentityServerConfiguration();

builder.Services.AddAuthentication()
    .AddJwtBearer("dcr", options =>
    {
        options.Authority = "https://identity.example.com";
        options.Audience = "IdentityServer.Configuration";
        options.TokenValidationParameters.ValidTypes = ["at+jwt"];
    });

builder.Services.AddAuthorization(options =>
{
    options.AddPolicy("dcr", policy =>
    {
        policy.AddAuthenticationSchemes("dcr");
        policy.RequireAuthenticatedUser();
        policy.RequireClaim("scope", "IdentityServer.Configuration");
    });
});

var app = builder.Build();

app.UseStaticFiles();
app.UseRouting();
app.UseIdentityServer();
app.UseAuthentication();
app.UseAuthorization();

app.MapRazorPages();
app.MapDynamicClientRegistration().RequireAuthorization("dcr");
```

How it works with your setup:
- The `dcr.manager` client (client_credentials, `AllowedScopes = IdentityServer.Configuration`) requests a token; the `IdentityServer.Configuration` scope is already defined as an `ApiScope`.
- `Audience = "IdentityServer.Configuration"` means the token needs that `aud`; either put the scope in an `ApiResource` with that name, or adjust/disable audience validation deliberately.
- `ValidTypes = ["at+jwt"]` rejects tokens that aren't access tokens.
- `RequireClaim("scope", ...)` enforces the scope. Missing token gives 401; missing scope gives 403.
- `UseAuthentication()` is needed alongside `UseAuthorization()` (your current pipeline only has the latter, though `UseIdentityServer()` adds IdentityServer's own auth handler).

Keep the scope assigned only to trusted admin/onboarding clients and rotate their secrets.
