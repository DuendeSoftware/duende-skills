# Fixing Verbose Logging and Filtering OperationCanceledException

## Problem

Your IdentityServer logs are too verbose in production and may expose sensitive data like tokens. The current `appsettings.json` has `Default` and `Microsoft.AspNetCore` both set to `Debug`, which is inappropriate for production.

## 1. Fix appsettings.json Logging Configuration

```json
{
  "Logging": {
    "LogLevel": {
      "Default": "Warning",
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

### Why These Levels Matter

- **`Duende.IdentityServer: Warning`** — This is the critical setting. At `Trace` or `Debug` levels, IdentityServer logs **sensitive data including tokens, authorization codes, and client secrets**. These levels must **never** be used in production.
- **`Default: Warning`** — Reduces overall log noise. Use `Information` only if you need general application flow details.
- **`Microsoft.AspNetCore: Warning`** — Reduces ASP.NET Core framework noise.

If you need temporary troubleshooting, briefly raise `Duende.IdentityServer` to `Information` — but never `Debug` or `Trace` in production.

## 2. Filter OperationCanceledException

When clients disconnect or cancel requests (common with browser navigation or timeouts), ASP.NET Core throws `OperationCanceledException`. These fill your logs with noise. Configure the IdentityServer exception logging filter:

```csharp
var builder = WebApplication.CreateBuilder(args);

builder.Services.AddIdentityServer(options =>
{
    // Filter out noise from cancelled requests
    options.Logging.UnhandledExceptionLoggingFilter = (ctx, ex) =>
    {
        // Suppress OperationCanceledException when the request was aborted
        if (ctx.RequestAborted.IsCancellationRequested && ex is OperationCanceledException)
            return false; // Don't log

        return true; // Log everything else
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

### How the Filter Works

The `UnhandledExceptionLoggingFilter` is a `Func<HttpContext, Exception, bool>`:
- **Return `false`** to suppress the log entry
- **Return `true`** to log the exception normally

The filter checks two conditions:
1. `ctx.RequestAborted.IsCancellationRequested` — the client disconnected
2. `ex is OperationCanceledException` — the exception is a cancellation

When both are true, the exception is just a normal client disconnect, not an actual error worth logging.

**Note**: This filter is actually the default behavior in IdentityServer, but you may need to configure it explicitly if you've customized exception handling or want to extend the filtering to suppress other noise.
