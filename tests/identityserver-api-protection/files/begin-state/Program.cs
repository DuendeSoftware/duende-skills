// Program.cs — Minimal Web API with no authentication configured yet
var builder = WebApplication.CreateBuilder(args);

builder.Services.AddControllers();

var app = builder.Build();

app.UseRouting();

app.MapControllers();

// Minimal API endpoints (unprotected)
app.MapGet("/data", () => Results.Ok(new { message = "Public data" }));
app.MapPost("/data", (DataModel model) => Results.Created($"/data/{model.Id}", model));
app.MapDelete("/data/{id}", (int id) => Results.NoContent());

app.Run();

public record DataModel(int Id, string Name, string Description);
