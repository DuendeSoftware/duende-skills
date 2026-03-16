# Fixing Verbose IdentityServer Logging in Production

## Problem

Your current `appsettings.json` has `Debug` level logging across the board. For Duende IdentityServer, **`Trace` and `Debug` log levels expose sensitive data including tokens, authorization codes, and client secrets**. This is a security risk in production and generates excessive log volume.

## Step 1: Fix appsettings.json Logging Levels

Replace your current logging configuration with production-appropriate levels:

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

### Log Level Guidelines

| Level | Usage | Production? |
|-------|-------|-------------|
| `Trace` | **Exposes tokens and sensitive data** | **NEVER** |
| `Debug` | Internal flow and decisions — **also exposes sensitive data** | **NEVER** |
| `Information` | General application flow | Short-term troubleshooting only |
| `Warning` | Abnormal or unexpected events | **Recommended default** |
| `Error` | Failed validation, unhandled exceptions | Always enabled |
| `Critical` | Missing store implementations, invalid key material | Always enabled |

Setting `Duende.IdentityServer` to `Warning` ensures you still see abnormal conditions and errors while eliminating the verbose internal processing logs and sensitive data exposure.

Setting `Default` to `Information` (from `Debug`) reduces noise from all other components while keeping useful general flow information.

## Step 2: Filter OperationCanceledException

When clients abort requests (e.g., navigating away during a login flow), ASP.NET Core throws `OperationCanceledException`. These are expected and harmless, but they pollute your error logs. IdentityServer provides a built-in filter for this.

Update your `Program.cs`:

```csharp
using Duende.IdentityServer;
using Microsoft.EntityFrameworkCore;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddIdentityServer(options =>
{
    // Filter out OperationCanceledException noise from cancelled requests
    options.Logging.UnhandledExceptionLoggingFilter = (ctx, ex) =>
    {
        // Return false to suppress logging, true to log the exception
        if (ctx.RequestAborted.IsCancellationRequested && ex is OperationCanceledException)
            return false;

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

The `UnhandledExceptionLoggingFilter` receives the `HttpContext` and the exception. When the request has been aborted (`ctx.RequestAborted.IsCancellationRequested`) and the exception is an `OperationCanceledException`, returning `false` suppresses the log entry. All other exceptions are still logged normally.

## Summary

1. **Set `Default` to `Information`** — stop the firehose of debug logs from all components
2. **Set `Duende.IdentityServer` to `Warning`** — stop token values and internal flow details from appearing in logs
3. **Never use `Trace` or `Debug` in production** — these levels intentionally include sensitive data for debugging purposes
4. **Filter `OperationCanceledException`** — use `options.Logging.UnhandledExceptionLoggingFilter` to suppress expected cancellation noise
