# JWT Bearer Authentication Setup

Here's how to configure JWT Bearer authentication for your API:

```csharp
var builder = WebApplication.CreateBuilder(args);

builder.Services.AddAuthentication("Bearer")
    .AddJwtBearer("Bearer", options =>
    {
        options.Authority = "https://identity.example.com";
        options.Audience = "catalog-api";

        options.TokenValidationParameters = new Microsoft.IdentityModel.Tokens.TokenValidationParameters
        {
            ValidateAudience = true,
            ValidAudience = "catalog-api",
            ValidateIssuer = true
        };
    });

builder.Services.AddAuthorization();

var app = builder.Build();

app.UseAuthentication();
app.UseAuthorization();

app.MapGet("/", () => "Hello World!").RequireAuthorization();

app.Run();
```

## What This Does

1. **Authority**: Points to your IdentityServer instance. The JWT handler will automatically discover the signing keys via the `.well-known/openid-configuration` endpoint.

2. **Audience**: Ensures the API only accepts tokens intended for `catalog-api`.

3. **Token Validation**: Validates the issuer and audience to ensure the token is legitimate.

4. **Middleware Ordering**: `UseAuthentication()` must come before `UseAuthorization()` so the identity is available for authorization checks.

To access user information in your endpoints, you can use `User.Identity.Name` and `User.Claims` to get the authenticated user's details.
