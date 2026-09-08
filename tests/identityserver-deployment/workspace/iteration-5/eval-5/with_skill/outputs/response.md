# Hardening IdentityServer logging for production

Two problems to fix: (1) verbose log levels that expose token values, and (2) noise from `OperationCanceledException` on cancelled requests.

## 1. Fix the log levels in appsettings

Your current `appsettings.json` uses `Debug` everywhere — that's the source of the token values in your logs. **`Trace` and `Debug` for `Duende.IdentityServer` log sensitive data including raw tokens and must never be used in production.** Use `Warning` for the IdentityServer category in production, and set the default to `Information` or `Warning` instead of `Debug`.

Best practice is to keep a permissive `appsettings.Development.json` and a locked-down `appsettings.Production.json` (or `appsettings.json` if that's your prod baseline):

```jsonc
// appsettings.Production.json
{
  "Logging": {
    "LogLevel": {
      "Default": "Warning",
      "Microsoft.AspNetCore": "Warning",
      "Duende.IdentityServer": "Warning"
    }
  }
}
```

If you only have one `appsettings.json`, change it to:

```jsonc
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

Log level reference for the `Duende.IdentityServer` category:

| Level         | Use                                                    |
| ------------- | ------------------------------------------------------ |
| `Trace`       | Sensitive data (tokens!) — **never** in production      |
| `Debug`       | Internal flow — short-term debugging only               |
| `Information` | General flow                                            |
| `Warning`     | **Default for production**                               |
| `Error`       | Failed validation, unhandled exceptions                 |
| `Critical`    | Missing stores, invalid key material                    |

Only temporarily raise to `Information`/`Debug` when actively troubleshooting, then revert.

## 2. Suppress OperationCanceledException noise

When a client aborts a request (browser navigates away, timeout), the framework raises `OperationCanceledException`. IdentityServer lets you filter which unhandled exceptions get logged via `options.Logging.UnhandledExceptionLoggingFilter`. Return `false` to suppress logging for cancelled requests:

```csharp
// Program.cs
builder.Services.AddIdentityServer(options =>
{
    options.Logging.UnhandledExceptionLoggingFilter = (ctx, ex) =>
    {
        // Suppress cancellation noise from aborted requests
        if (ctx.RequestAborted.IsCancellationRequested && ex is OperationCanceledException)
        {
            return false; // don't log
        }

        return true; // log everything else
    };
})
    .AddInMemoryIdentityResources(Config.IdentityResources)
    .AddInMemoryApiScopes(Config.ApiScopes)
    .AddInMemoryClients(Config.Clients);
```

The filter receives the `HttpContext` and the exception. Checking `ctx.RequestAborted.IsCancellationRequested` ensures you only suppress cancellations that came from the client aborting — genuine `OperationCanceledException`s from other causes still get logged. (This particular behavior is actually the default, but setting the filter explicitly makes the intent clear and lets you extend it.)

## Result

- No more token values in logs (Warning level for `Duende.IdentityServer`).
- Default level is `Information`/`Warning`, not `Debug`.
- Cancelled-request `OperationCanceledException` entries are filtered out.
