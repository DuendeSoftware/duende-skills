# Setting Up JWT Bearer Authentication for Your API

To protect your minimal API with JWT bearer authentication, follow these steps:

## Step 1: Install the NuGet Package

```bash
dotnet add package Microsoft.AspNetCore.Authentication.JwtBearer
```

## Step 2: Configure Authentication

Update your `Program.cs`:

```csharp
var builder = WebApplication.CreateBuilder(args);

builder.Services.AddControllers();

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

- **Authority**: Points to your IdentityServer instance. The middleware will automatically download the discovery document and signing keys.
- **Audience**: Must match the API resource name configured in IdentityServer.
- **UseAuthentication/UseAuthorization**: These middleware components must be added in the correct order — authentication first, then authorization.

The JWT bearer handler will validate incoming access tokens by checking the signature against IdentityServer's public keys, verifying the issuer and audience claims, and checking token expiration.
