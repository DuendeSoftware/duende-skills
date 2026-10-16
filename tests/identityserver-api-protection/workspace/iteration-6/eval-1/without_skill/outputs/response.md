# JWT bearer protection for your API

Add the package:

```
dotnet add package Microsoft.AspNetCore.Authentication.JwtBearer
```

**Program.cs**

```csharp
using Microsoft.AspNetCore.Authentication.JwtBearer;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddControllers();

builder.Services
    .AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(options =>
    {
        options.Authority = builder.Configuration["IdentityServer:Authority"]; // https://identity.example.com
        options.Audience = "api1";
        options.RequireHttpsMetadata = true;
        options.MapInboundClaims = false;
        options.TokenValidationParameters = new()
        {
            ValidateIssuer = true,
            ValidateAudience = true,
            ValidateLifetime = true,
            ValidateIssuerSigningKey = true,
            ValidTypes = new[] { "at+jwt" },   // only accept access tokens
            ClockSkew = TimeSpan.FromMinutes(1)
        };
    });

builder.Services.AddAuthorization(options =>
{
    options.FallbackPolicy = new AuthorizationPolicyBuilder()
        .RequireAuthenticatedUser()
        .Build();
});

var app = builder.Build();

app.UseRouting();
app.UseAuthentication();
app.UseAuthorization();

app.MapControllers();

app.MapGet("/data", () => Results.Ok(new { message = "Protected data" }));
app.MapPost("/data", (DataModel model) => Results.Created($"/data/{model.Id}", model));
app.MapDelete("/data/{id}", (int id) => Results.NoContent());

app.Run();

public record DataModel(int Id, string Name, string Description);
```

## Security notes
- **Authority** makes the handler fetch discovery and JWKS keys, validating signature and issuer automatically.
- **Audience = api1** ensures tokens for other APIs are rejected.
- **Always keep HTTPS metadata required** in production.
- **`ValidTypes = at+jwt`** blocks ID tokens being used as access tokens (IdentityServer emits `at+jwt`).
- **Order matters**: `UseAuthentication` before `UseAuthorization`.
- **Fallback policy** makes every endpoint require authentication by default; opt out with `.AllowAnonymous()`.
- Add scope checks with policies (`RequireClaim("scope", "api1")`) for finer control.
