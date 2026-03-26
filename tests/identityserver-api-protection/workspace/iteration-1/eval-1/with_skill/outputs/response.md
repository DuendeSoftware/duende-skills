# Protecting Your Minimal API with JWT Bearer Authentication

To protect your API with JWT bearer authentication from IdentityServer, you need to:

1. Add the JWT bearer NuGet package
2. Configure the authentication handler
3. Set up the middleware pipeline correctly

## Step 1: Add the NuGet Package

```bash
dotnet add package Microsoft.AspNetCore.Authentication.JwtBearer
```

## Step 2: Configure JWT Bearer Authentication

Update your `Program.cs`:

```csharp
var builder = WebApplication.CreateBuilder(args);

builder.Services.AddControllers();

// Add JWT bearer authentication
builder.Services.AddAuthentication("Bearer")
    .AddJwtBearer("Bearer", options =>
    {
        options.Authority = "https://identity.example.com";
        options.Audience = "api1";

        // Critical: Validate the at+jwt type header to prevent JWT confusion attacks
        options.TokenValidationParameters.ValidTypes = ["at+jwt"];
    });

builder.Services.AddAuthorization();

var app = builder.Build();

app.UseRouting();

// Authentication must come before Authorization
app.UseAuthentication();
app.UseAuthorization();

app.MapControllers();

// Minimal API endpoints (now protected)
app.MapGet("/data", () => Results.Ok(new { message = "Protected data" }))
    .RequireAuthorization();
app.MapPost("/data", (DataModel model) => Results.Created($"/data/{model.Id}", model))
    .RequireAuthorization();
app.MapDelete("/data/{id}", (int id) => Results.NoContent())
    .RequireAuthorization();

app.Run();

public record DataModel(int Id, string Name, string Description);
```

## Key Configuration Details

### Authority
The `Authority` is set to `https://identity.example.com` — this is where the JWT bearer handler will download the discovery document and JWKS (signing keys) for token validation.

### Audience
The `Audience` is set to `api1`, which must match the `ApiResource` name configured in IdentityServer. This validates the `aud` claim in the access token.

### ValidTypes (Critical for Security)
Setting `TokenValidationParameters.ValidTypes = ["at+jwt"]` is essential. Without this, an attacker could present an identity token (also a JWT signed by the same issuer) to the API — this is known as a JWT confusion attack. IdentityServer sets the `typ` header to `at+jwt` on all access token JWTs per RFC 9068.

### Middleware Ordering
`UseAuthentication()` must come before `UseAuthorization()` in the pipeline. This ensures the request is authenticated before authorization policies are evaluated.

## Updated WebApi.csproj

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
