# Securing /connect/dcr with JWT bearer + scope

`MapDynamicClientRegistration()` returns an endpoint convention builder, so attach an authorization policy to it.

```csharp
builder.Services.AddAuthentication("token")
    .AddJwtBearer("token", o =>
    {
        o.Authority = "https://identity.example.com";
        o.MapInboundClaims = false;
        o.TokenValidationParameters.ValidateAudience = false; // or set a real audience
        o.TokenValidationParameters.ValidTypes = new[] { "at+jwt" };
    });

builder.Services.AddAuthorization(options =>
{
    options.AddPolicy("DCR", policy =>
    {
        policy.AddAuthenticationSchemes("token");
        policy.RequireAuthenticatedUser();
        policy.RequireClaim("scope", "IdentityServer.Configuration");
    });
});

// pipeline
app.UseIdentityServer();
app.UseAuthentication();
app.UseAuthorization();

app.MapDynamicClientRegistration().RequireAuthorization("DCR");
```

Notes:
- Your `dcr.manager` client (client_credentials, scope `IdentityServer.Configuration`) fetches the token.
- Authentication/authorization middleware must run before endpoints execute.
- Don't give the scope to ordinary clients.
- `ValidTypes = at+jwt` avoids accepting other JWTs; also consider an audience check.
- Unauthenticated calls get 401; missing scope gets 403.
