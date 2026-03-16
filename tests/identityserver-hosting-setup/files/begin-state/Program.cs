var builder = WebApplication.CreateBuilder(args);

// TODO: Configure IdentityServer here

var app = builder.Build();

// TODO: Add middleware here

app.MapGet("/", () => "Hello World!");

app.Run();
