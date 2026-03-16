using Microsoft.AspNetCore.Authentication.JwtBearer;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(options =>
    {
        options.Authority = builder.Configuration["Authentication:Authority"];
        options.Audience = builder.Configuration["Authentication:Audience"];
    });

var app = builder.Build();

app.UseAuthentication();

// Products endpoints — no authorization configured yet
app.MapGet("/products", () => Results.Ok(new[]
{
    new { Id = 1, Name = "Widget", Price = 9.99 },
    new { Id = 2, Name = "Gadget", Price = 19.99 }
}));

app.MapPost("/products", (object product) => Results.Created("/products/3", product));

app.MapDelete("/products/{id}", (int id) => Results.NoContent());

// Admin endpoints — no authorization configured yet
app.MapGet("/admin/users", () => Results.Ok(new[] { "alice", "bob" }));

app.MapPost("/admin/users", (object user) => Results.Created("/admin/users/3", user));

// Documents endpoint — no authorization configured yet
app.MapGet("/documents/{id}", (int id) =>
    Results.Ok(new { Id = id, Title = "Quarterly Report", Department = "finance", OwnerId = "user-1" }));

app.MapPut("/documents/{id}", (int id, object doc) => Results.NoContent());

// Health check — should remain publicly accessible
app.MapGet("/health", () => Results.Ok("healthy"));

app.Run();
