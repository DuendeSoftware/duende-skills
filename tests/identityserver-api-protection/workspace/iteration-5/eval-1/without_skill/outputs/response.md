# Adding JWT bearer authentication to your minimal API

Here's how to secure the API so it only accepts valid JWTs issued by your IdentityServer at `https://identity.example.com` for the `api1` resource.

## 1. Install the authentication package

```bash
dotnet add package Microsoft.AspNetCore.Authentication.JwtBearer
```

## 2. Update `Program.cs`

```csharp
var builder = WebApplication.CreateBuilder(args);

builder.Services.AddControllers();

builder.Services.AddAuthentication(options =>
{
    options.DefaultAuthenticateScheme = JwtBearerDefaults.AuthenticationScheme;
    options.DefaultChallengeScheme = JwtBearerDefaults.AuthenticationScheme;
})
.AddJwtBearer(options =>
{
    options.Authority = "https://identity.example.com";
    options.Audience = "api1";
    options.RequireHttpsMetadata = true; // keep true in production

    options.TokenValidationParameters = new TokenValidationParameters
    {
        ValidateIssuer = true,
        ValidateAudience = true,
        ValidAudience = "api1",
        ValidateLifetime = true,
        ValidateIssuerSigningKey = true
    };
});

builder.Services.AddAuthorization();

var app = builder.Build();

app.UseRouting();

app.UseAuthentication();
app.UseAuthorization();

app.MapControllers();

app.MapGet("/data", () => Results.Ok(new { message = "Protected data" }))
    .RequireAuthorization();
app.MapPost("/data", (DataModel model) => Results.Created($"/data/{model.Id}", model))
    .RequireAuthorization();
app.MapDelete("/data/{id}", (int id) => Results.NoContent())
    .RequireAuthorization();

app.Run();

public record DataModel(int Id, string Name, string Description);
```

## Notes on security

- The `Authority` lets the middleware fetch the OpenID Connect discovery document and signing keys automatically, so signatures are verified against the issuer's JWKS.
- Setting `Audience`/`ValidAudience` to `api1` ensures tokens minted for other APIs are rejected.
- Keep `RequireHttpsMetadata = true` so metadata is only fetched over TLS.
- `UseAuthentication()` must run before `UseAuthorization()`, otherwise the request principal won't be populated when authorization runs.
- Consider adding `ValidateLifetime` clock-skew tuning and issuer validation as shown.

With `.RequireAuthorization()` on each endpoint, unauthenticated requests will receive a `401`.
