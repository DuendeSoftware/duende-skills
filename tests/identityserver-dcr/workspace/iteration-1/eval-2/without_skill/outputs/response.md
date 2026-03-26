# Securing DCR with JWT Bearer

```csharp
builder.Services.AddAuthentication()
    .AddJwtBearer("dcr-scheme", options =>
    {
        options.Authority = "https://identity.example.com";
        options.Audience = "dcr-api";
    });

builder.Services.AddAuthorization(options =>
{
    options.AddPolicy("DcrPolicy", policy =>
    {
        policy.AddAuthenticationSchemes("dcr-scheme");
        policy.RequireAuthenticatedUser();
        policy.RequireClaim("scope", "dcr:manage");
    });
});

app.MapDynamicClientRegistration()
    .RequireAuthorization("DcrPolicy");
```

This ensures only callers with a valid token and the `dcr:manage` scope can register clients.
