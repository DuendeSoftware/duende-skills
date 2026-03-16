// Program.cs — Bare ASP.NET Core web app, no BFF configured yet
var builder = WebApplication.CreateBuilder(args);

builder.Services.AddAuthorization();

var app = builder.Build();

app.UseRouting();
app.UseAuthorization();

app.MapGet("/", () => "Hello World");

app.Run();
