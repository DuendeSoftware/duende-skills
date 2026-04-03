# Setting Up JWT Bearer Authentication

## Install Package

```bash
dotnet add package Microsoft.AspNetCore.Authentication.JwtBearer
```

## Configure in Program.cs

```csharp
var builder = WebApplication.CreateBuilder(args);

builder.Services.AddControllers();

builder.Services.AddAuthentication("Bearer")
    .AddJwtBearer("Bearer", options =>
    {
        options.Authority = "https://identity.example.com";
        options.Audience = "api1";
    });

var app = builder.Build();

app.UseRouting();
app.UseAuthentication();
app.UseAuthorization();

app.MapControllers();

app.MapGet("/data", () => Results.Ok(new { message = "Protected data" }))
    .RequireAuthorization();
app.MapPost("/data", (DataModel model) => Results.Created($"/data/{model.Id}", model))
    .RequireAuthorization();

app.Run();

public record DataModel(int Id, string Name, string Description);
```

This sets up your API to validate JWTs from the IdentityServer authority. The `Audience` ensures only tokens intended for `api1` are accepted.
