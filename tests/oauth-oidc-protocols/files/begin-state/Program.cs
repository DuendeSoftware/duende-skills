var builder = WebApplication.CreateBuilder(args);

// TODO: Configure services here

builder.Services.AddAuthorization();

var app = builder.Build();

// TODO: Add middleware and endpoints here

app.MapGet("/", () => "Hello World!");

app.Run();
