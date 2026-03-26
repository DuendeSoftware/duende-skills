# Fixing Production Logging

## Update appsettings.json

Change the log levels to reduce noise:

```json
{
  "Logging": {
    "LogLevel": {
      "Default": "Information",
      "Microsoft.AspNetCore": "Warning"
    }
  },
  "AllowedHosts": "*",
  "ConnectionStrings": {
    "DefaultConnection": "Server=localhost;Database=IdentityServer;Trusted_Connection=True;MultipleActiveResultSets=true"
  }
}
```

## Handle OperationCanceledException

You can add middleware to catch and suppress these:

```csharp
app.Use(async (context, next) =>
{
    try
    {
        await next(context);
    }
    catch (OperationCanceledException) when (context.RequestAborted.IsCancellationRequested)
    {
        // Client disconnected, ignore
        context.Response.StatusCode = 499; // Client Closed Request
    }
});
```

This catches cancelled requests before they become unhandled exceptions in the logs.
