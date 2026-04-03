# Production Logging Configuration for IdentityServer

## Problem

Your IdentityServer logs are verbose because the default log levels are set to `Debug`, and at `Trace`/`Debug` levels, IdentityServer logs **sensitive data including token values**. Additionally, `OperationCanceledException` noise from cancelled requests pollutes the logs.

## Fix appsettings.json (or appsettings.Production.json)

```json
{
  "Logging": {
    "LogLevel": {
      "Default": "Information",
      "Microsoft.AspNetCore": "Warning",
      "Duende.IdentityServer": "Warning"
    }
  },
  "AllowedHosts": "*",
  "ConnectionStrings": {
    "DefaultConnection": "Server=localhost;Database=IdentityServer;Trusted_Connection=True;MultipleActiveResultSets=true"
  }
}
```

### Key Changes

- **`Default`**: Changed from `Debug` to `Information`. `Debug` produces too much noise in production.
- **`Duende.IdentityServer`**: Set to `Warning`. The `Trace` and `Debug` levels expose sensitive data like tokens, authorization codes, and other secrets in the log output. **Never enable Trace or Debug in production.**
- **`Microsoft.AspNetCore`**: Set to `Warning` to reduce framework noise.

## Filter OperationCanceledException in Program.cs

```csharp
using Duende.IdentityServer;
using Microsoft.EntityFrameworkCore;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddIdentityServer(options =>
{
    // Filter out OperationCanceledException when the client disconnects
    options.Logging.UnhandledExceptionLoggingFilter = (ctx, ex) =>
    {
        // When the request is aborted (client disconnected) and the exception
        // is OperationCanceledException, suppress the log entry (return false)
        if (ctx.RequestAborted.IsCancellationRequested && ex is OperationCanceledException)
            return false;

        // Log all other exceptions normally
        return true;
    };
})
    .AddInMemoryIdentityResources(Config.IdentityResources)
    .AddInMemoryApiScopes(Config.ApiScopes)
    .AddInMemoryClients(Config.Clients);

var app = builder.Build();

app.UseIdentityServer();

app.MapGet("/", () => "IdentityServer is running");

app.Run();
```

## Summary

1. Set `Duende.IdentityServer` log level to `Warning` (or higher) in production — never `Trace` or `Debug` which expose tokens.
2. Set `Default` to `Information` or `Warning` — not `Debug`.
3. Use `options.Logging.UnhandledExceptionLoggingFilter` to suppress `OperationCanceledException` when `ctx.RequestAborted.IsCancellationRequested` is `true`, returning `false` to suppress the log.
