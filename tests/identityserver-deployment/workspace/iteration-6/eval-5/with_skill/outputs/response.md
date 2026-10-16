# Production logging

`Debug` (and `Trace`) expose sensitive data such as tokens — never use them in production. `Trace` is the sensitive-data level; `Debug` is for short-term troubleshooting only. Set `Default` and `Duende.IdentityServer` to `Warning` in `appsettings.Production.json`:

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

Raise `Duende.IdentityServer` to `Information` only temporarily when troubleshooting. (Move the connection string to secrets/environment variables too.)

## Filter OperationCanceledException

```csharp
builder.Services.AddIdentityServer(options =>
{
    options.Logging.UnhandledExceptionLoggingFilter = (ctx, ex) =>
    {
        // return false to suppress, true to log
        if (ctx.RequestAborted.IsCancellationRequested && ex is OperationCanceledException)
            return false;   // this is already the default
        return true;
    };
})
.AddInMemoryIdentityResources(Config.IdentityResources)
.AddInMemoryApiScopes(Config.ApiScopes)
.AddInMemoryClients(Config.Clients);
```

Cancelled-request exceptions are already filtered by default; the filter lets you customize it. Level reference: Trace = tokens; Debug = internal flow; Information = general flow; Warning = abnormal events; Error = failed validation/unhandled; Critical = missing stores/invalid key material.
