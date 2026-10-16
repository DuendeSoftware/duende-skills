# Securing your API with JWT bearer authentication

```bash
dotnet add package Microsoft.AspNetCore.Authentication.JwtBearer
```

**Program.cs**

```csharp
var builder = WebApplication.CreateBuilder(args);

builder.Services.AddControllers();

builder.Services.AddAuthentication("Bearer")
    .AddJwtBearer("Bearer", options =>
    {
        options.Authority = builder.Configuration["IdentityServer:Authority"]; // https://identity.example.com
        options.Audience = "api1";

        // Critical: protects against JWT confusion (e.g. identity tokens used as access tokens)
        options.TokenValidationParameters.ValidTypes = ["at+jwt"];
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

## Why each piece matters

- **`Authority`**: the handler uses discovery and JWKS to verify signature and issuer.
- **`Audience = "api1"`**: must match the `ApiResource` name in IdentityServer. If omitted, audience validation is skipped, which isn't recommended. A mismatch yields a 401 with little detail in logs.
- **`ValidTypes = ["at+jwt"]`**: IdentityServer sets `typ: at+jwt` on access tokens (RFC 9068, `AccessTokenJwtType`). Without this check, an identity token, which is also a JWT signed by the same issuer, could be accepted by your API.
- **Middleware order**: `UseAuthentication()` then `UseAuthorization()`.
- **Fallback policy**: all endpoints, including the currently public ones, now require an authenticated user by default; use `.AllowAnonymous()` to opt out.

## Next step: scopes
Authentication only proves the token is valid. Add scope policies:

```csharp
options.AddPolicy("read", p => p.RequireAuthenticatedUser().RequireClaim("scope", "api1.read"));
options.AddPolicy("write", p => p.RequireAuthenticatedUser().RequireClaim("scope", "api1.write"));
// app.MapGet("/data", ...).RequireAuthorization("read");
```

Keep `Authority` in configuration (as in your appsettings.json) and use HTTPS only.
