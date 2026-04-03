# Fix Verbose Logging in IdentityServer Production

## Fix appsettings.json

```json
{
  "Logging": {
    "LogLevel": {
      "Default": "Warning",
      "Microsoft.AspNetCore": "Warning"
    }
  },
  "AllowedHosts": "*",
  "ConnectionStrings": {
    "DefaultConnection": "Server=localhost;Database=IdentityServer;Trusted_Connection=True;MultipleActiveResultSets=true"
  }
}
```

Change the Default log level from Debug to Warning. This reduces the volume significantly.

## Suppress OperationCanceledException

For handling cancelled requests, you can add exception handling middleware:

```csharp
var builder = WebApplication.CreateBuilder(args);

builder.Services.AddIdentityServer()
    .AddInMemoryIdentityResources(Config.IdentityResources)
    .AddInMemoryApiScopes(Config.ApiScopes)
    .AddInMemoryClients(Config.Clients);

var app = builder.Build();

app.Use(async (context, next) =>
{
    try
    {
        await next();
    }
    catch (OperationCanceledException) when (context.RequestAborted.IsCancellationRequested)
    {
        // Silently ignore cancelled requests
        context.Response.StatusCode = 499; // Client Closed Request
    }
});

app.UseIdentityServer();

app.MapGet("/", () => "IdentityServer is running");

app.Run();
```

This catches `OperationCanceledException` when the client disconnects and prevents it from being logged as an unhandled exception.
