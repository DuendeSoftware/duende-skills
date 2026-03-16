# Protecting a Minimal API with JWT Bearer Authentication

Here's how to set up JWT bearer authentication for your minimal API with IdentityServer as the authority.

## Step 1: Add the NuGet Package

```bash
dotnet add package Microsoft.AspNetCore.Authentication.JwtBearer
```

## Step 2: Configure Authentication and Authorization

Update your `Program.cs`:

```csharp
// Program.cs
var builder = WebApplication.CreateBuilder(args);

builder.Services.AddControllers();

// Add JWT Bearer authentication
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

// Important: UseAuthentication must come before UseAuthorization
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

## Step 3: Update the Project File

Your `WebApi.csproj` should include the JWT bearer package:

```xml
<Project Sdk="Microsoft.NET.Sdk.Web">
  <PropertyGroup>
    <TargetFramework>net9.0</TargetFramework>
    <Nullable>enable</Nullable>
    <ImplicitUsings>enable</ImplicitUsings>
  </PropertyGroup>

  <ItemGroup>
    <PackageReference Include="Microsoft.AspNetCore.Authentication.JwtBearer" />
  </ItemGroup>
</Project>
```

## Key Security Points

1. **`Authority`** — Points to your IdentityServer instance. The JWT bearer handler downloads the discovery document and JWKS from this URL to validate token signatures.

2. **`Audience`** — Must match the `ApiResource` name configured in IdentityServer (`api1`). This validates the `aud` claim in the access token.

3. **`ValidTypes = ["at+jwt"]`** — This is critical for security. It validates the `typ` header in the JWT is `at+jwt` (per RFC 9068). Without this, an attacker could present an identity token (which is also a JWT signed by the same issuer) to your API — a JWT confusion attack.

4. **Middleware ordering** — `UseAuthentication()` must come before `UseAuthorization()` in the pipeline. Reversing the order means authorization runs before the user identity is established, and all requests will be treated as anonymous.
