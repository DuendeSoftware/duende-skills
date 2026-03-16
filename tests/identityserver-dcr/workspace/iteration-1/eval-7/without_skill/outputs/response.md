# Hosting DCR Separately from IdentityServer

If you want to separate your DCR endpoint from the main IdentityServer, you can create a standalone application that handles client registration.

## Separate DCR Host Program.cs

```csharp
var builder = WebApplication.CreateBuilder(args);

// Add IdentityServer configuration for the separate DCR host
builder.Services.AddIdentityServerConfiguration(options =>
{
    options.IdentityServerBaseUrl = "https://identity.example.com";
});

// Configure authentication to validate tokens from the main IdentityServer
builder.Services.AddAuthentication("Bearer")
    .AddJwtBearer("Bearer", options =>
    {
        options.Authority = "https://identity.example.com";
        options.TokenValidationParameters = new Microsoft.IdentityModel.Tokens.TokenValidationParameters
        {
            ValidateAudience = true,
            ValidAudience = "IdentityServer.Configuration"
        };
    });

builder.Services.AddAuthorization(options =>
{
    options.AddPolicy("DcrPolicy", policy =>
    {
        policy.RequireAuthenticatedUser();
        policy.RequireClaim("scope", "IdentityServer.Configuration");
    });
});

var app = builder.Build();

app.UseAuthentication();
app.UseAuthorization();

app.MapDynamicClientRegistration()
    .RequireAuthorization("DcrPolicy");

app.Run();
```

## Important Considerations

1. **Shared Data Store**: The DCR host needs access to the same client database that your main IdentityServer uses. When a client is registered via DCR, IdentityServer needs to be able to find it.

2. **Authentication**: The DCR host validates tokens against the main IdentityServer. Callers must obtain a token from the main IdentityServer with the appropriate scope.

3. **No IdentityServer Middleware**: This separate host does NOT run the full IdentityServer middleware — it only handles DCR requests.

4. **Networking**: Ensure the DCR host can reach the main IdentityServer for token validation (discovery document, JWKS).
