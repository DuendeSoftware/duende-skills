# Production logging

Tokens appear because `Debug`/`Trace` levels in Duende log request details. Use Information/Warning in production.

```json
{
  "Logging": {
    "LogLevel": {
      "Default": "Warning",
      "Microsoft.AspNetCore": "Warning",
      "Microsoft.EntityFrameworkCore": "Warning",
      "Duende.IdentityServer": "Information",
      "Duende.IdentityServer.Validation": "Warning"
    }
  },
  "AllowedHosts": "*",
  "ConnectionStrings": {
    "DefaultConnection": "Server=localhost;Database=IdentityServer;Trusted_Connection=True;MultipleActiveResultSets=true"
  }
}
```
Never use `Debug` for `Duende.IdentityServer` in production — it can log request parameters, tokens and claims. Also move the connection string to secrets/environment variables.

## Filtering OperationCanceledException

Cancelled requests (client disconnects) generate noise. With Serilog:

```csharp
builder.Host.UseSerilog((ctx, cfg) => cfg
    .ReadFrom.Configuration(ctx.Configuration)
    .Filter.ByExcluding(e => e.Exception is OperationCanceledException));
```

Or, with built-in logging, avoid it with middleware:

```csharp
app.Use(async (ctx, next) =>
{
    try { await next(); }
    catch (OperationCanceledException) when (ctx.RequestAborted.IsCancellationRequested)
    {
        ctx.Response.StatusCode = 499;
    }
});
```
Place it early in the pipeline.
