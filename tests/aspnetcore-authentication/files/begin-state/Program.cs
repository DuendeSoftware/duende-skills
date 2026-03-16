var builder = WebApplication.CreateBuilder(args);

// TODO: Configure authentication here

builder.Services.AddAuthorization();

var app = builder.Build();

// TODO: Add middleware here

app.MapGet("/", () => "Hello World!");

app.Run();
