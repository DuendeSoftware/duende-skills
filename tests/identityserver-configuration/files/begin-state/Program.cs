var builder = WebApplication.CreateBuilder(args);

// TODO: Configure Duende IdentityServer here

var app = builder.Build();

app.MapGet("/", () => "IdentityServer is running");

app.Run();
