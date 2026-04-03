# JWT Bearer Authentication for API

Here's how to set up JWT Bearer authentication for your API:

```csharp
var builder = WebApplication.CreateBuilder(args);

builder.Services.AddAuthentication("Bearer")
    .AddJwtBearer("Bearer", options =>
    {
        options.Authority = "https://identity.example.com";
        options.Audience = "catalog-api";
    });

builder.Services.AddAuthorization();

var app = builder.Build();

app.UseAuthentication();
app.UseAuthorization();

app.MapGet("/", () => "Hello World!")
    .RequireAuthorization();

app.Run();
```

## What This Does

- **Authority** is set to your IdentityServer URL. The handler will automatically download signing keys from the discovery document.
- **Audience** is set to `catalog-api` to validate the token's audience claim.
- `UseAuthentication()` is called before `UseAuthorization()` in the middleware pipeline.
- Any endpoint with `RequireAuthorization()` will require a valid JWT token.

For `User.Identity.Name` to work, you may need to ensure the `name` claim is included in the token. ASP.NET Core should map standard claims automatically.
