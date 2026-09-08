# Protecting your minimal API with JWT bearer authentication

Your API currently has no authentication. Below is a secure setup that validates JWT access tokens issued by IdentityServer.

## 1. Add the JWT bearer package

```bash
dotnet add package Microsoft.AspNetCore.Authentication.JwtBearer
```

Or in `WebApi.csproj`:

```xml
<Project Sdk="Microsoft.NET.Sdk.Web">

  <PropertyGroup>
    <TargetFramework>net10.0</TargetFramework>
    <Nullable>enable</Nullable>
    <ImplicitUsings>enable</ImplicitUsings>
  </PropertyGroup>

  <ItemGroup>
    <PackageReference Include="Microsoft.AspNetCore.Authentication.JwtBearer" Version="10.0.0" />
  </ItemGroup>

</Project>
```

## 2. Configure authentication in `Program.cs`

```csharp
// Program.cs
var builder = WebApplication.CreateBuilder(args);

builder.Services.AddControllers();

builder.Services.AddAuthentication("Bearer")
    .AddJwtBearer("Bearer", options =>
    {
        options.Authority = "https://identity.example.com";
        options.Audience = "api1";

        // CRITICAL: only accept access-token JWTs (typ header at+jwt).
        // Without this, an identity token signed by the same issuer could be
        // replayed as an access token (JWT confusion attack).
        options.TokenValidationParameters.ValidTypes = ["at+jwt"];
    });

builder.Services.AddAuthorization();

var app = builder.Build();

app.UseRouting();

// Authentication MUST come before Authorization.
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

## Why each piece matters

- **`Authority = "https://identity.example.com"`** — the API downloads the issuer's discovery document and JWKS from here to verify token signatures. No client secret is needed for JWT validation.
- **`Audience = "api1"`** — validates the `aud` claim against your `ApiResource` name in IdentityServer. A mismatch here is the #1 cause of silent `401`s.
- **`ValidTypes = ["at+jwt"]`** — IdentityServer stamps `typ: at+jwt` on access tokens (RFC 9068). Enforcing it blocks JWT confusion attacks.
- **Middleware order** — `UseAuthentication()` establishes the identity; `UseAuthorization()` enforces policy. Reversing them means the user is always anonymous at the authorization stage.

You can now protect endpoints with `.RequireAuthorization()` (or `[Authorize]` on controllers). Add named scope policies later if you need per-endpoint scope checks.
