using Microsoft.AspNetCore.Authorization;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddAuthentication("Bearer")
    .AddJwtBearer("Bearer", options =>
    {
        options.Authority = builder.Configuration["Authentication:Authority"];
        options.Audience = "my-api";
        options.MapInboundClaims = false;
    });

builder.Services.AddAuthorization(options =>
{
    options.AddPolicy("AdminOnly", policy =>
        policy.RequireClaim("role", "admin"));

    options.AddPolicy("ApiScope", policy =>
        policy.RequireClaim("scope", "api1"));
});

var app = builder.Build();

app.UseAuthentication();
app.UseAuthorization();

app.MapGet("/api/products", [Authorize(Policy = "ApiScope")] () =>
    Results.Ok(new[]
    {
        new { Id = 1, Name = "Widget", Price = 9.99 },
        new { Id = 2, Name = "Gadget", Price = 24.99 }
    }));

app.MapGet("/api/products/{id:int}", [Authorize(Policy = "ApiScope")] (int id) =>
    Results.Ok(new { Id = id, Name = "Widget", Price = 9.99 }));

app.MapDelete("/api/products/{id:int}", [Authorize(Policy = "AdminOnly")] (int id) =>
    Results.NoContent());

app.MapGet("/api/admin/users", [Authorize(Policy = "AdminOnly")] () =>
    Results.Ok(new[] { new { Id = 1, Name = "Alice" } }));

app.MapDelete("/api/admin/users/{id:int}", [Authorize(Policy = "AdminOnly")] (int id) =>
    Results.NoContent());

app.Run();

// Make Program accessible for WebApplicationFactory<Program>
public partial class Program { }
