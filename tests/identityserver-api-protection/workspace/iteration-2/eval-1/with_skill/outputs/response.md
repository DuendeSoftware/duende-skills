# Setting Up JWT Bearer Authentication with IdentityServer

## 1. Install the NuGet Package

```bash
dotnet add package Microsoft.AspNetCore.Authentication.JwtBearer
```

## 2. Configure Authentication in Program.cs

```csharp
// Program.cs
var builder = WebApplication.CreateBuilder(args);

builder.Services.AddControllers();

builder.Services.AddAuthentication("Bearer")
    .AddJwtBearer("Bearer", options =>
    {
        options.Authority = "https://identity.example.com";
        options.Audience = "api1";

        // Critical: Validate the at+jwt type header to prevent JWT confusion attacks.
        // Without this, an attacker could present an identity token (also a JWT signed
        // by the same issuer) to the API and it would be accepted.
        options.TokenValidationParameters.ValidTypes = ["at+jwt"];
    });

var app = builder.Build();

app.UseRouting();

// Authentication MUST come before Authorization in the middleware pipeline
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

## 3. Updated WebApi.csproj

```xml
<Project Sdk="Microsoft.NET.Sdk.Web">
  <PropertyGroup>
    <TargetFramework>net9.0</TargetFramework>
    <Nullable>enable</Nullable>
    <ImplicitUsings>enable</ImplicitUsings>
  </PropertyGroup>
  <ItemGroup>
    <PackageReference Include="Microsoft.AspNetCore.Authentication.JwtBearer" Version="9.0.0" />
  </ItemGroup>
</Project>
```

## Key Points

- **Authority**: Set to your IdentityServer URL. The JWT bearer handler uses this to discover the JWKS endpoint for signature validation.
- **Audience**: Must match the `ApiResource` name in IdentityServer (`api1`).
- **ValidTypes `["at+jwt"]`**: IdentityServer sets the `typ` header to `at+jwt` on all access token JWTs per RFC 9068. Validating this prevents JWT confusion attacks where an identity token could be presented as an access token.
- **Middleware ordering**: `UseAuthentication()` must be called before `UseAuthorization()`, otherwise the authorization middleware won't have access to the authenticated user.
