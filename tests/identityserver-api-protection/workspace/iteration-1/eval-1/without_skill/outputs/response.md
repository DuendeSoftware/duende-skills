# Protecting a Minimal API with JWT Bearer Authentication

Here's how to set up JWT bearer authentication for your ASP.NET Core minimal API.

## Step 1: Add the NuGet Package

```bash
dotnet add package Microsoft.AspNetCore.Authentication.JwtBearer
```

## Step 2: Configure Authentication

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
    });

builder.Services.AddAuthorization();

var app = builder.Build();

app.UseRouting();
app.UseAuthentication();
app.UseAuthorization();

app.MapControllers();

// Protected endpoints
app.MapGet("/data", () => Results.Ok(new { message = "Protected data" }))
    .RequireAuthorization();

app.MapPost("/data", (DataModel model) => Results.Created($"/data/{model.Id}", model))
    .RequireAuthorization();

app.MapDelete("/data/{id}", (int id) => Results.NoContent())
    .RequireAuthorization();

app.Run();

public record DataModel(int Id, string Name, string Description);
```

## How It Works

- **`Authority`** tells the JWT bearer handler where to find the OpenID Connect discovery document and signing keys for token validation.
- **`Audience`** validates the `aud` claim in the token matches your API.
- `UseAuthentication()` and `UseAuthorization()` middleware handle the authentication and authorization pipeline.

This setup will validate JWTs issued by your IdentityServer and ensure only authenticated requests reach your API endpoints.
