In the service defaults `Extensions.cs` (`ConfigureOpenTelemetry`), use **string literals** so the shared project needs no Duende package reference:

```csharp
.WithMetrics(metrics =>
{
    metrics
        .AddMeter("Duende.IdentityServer")
        .AddAspNetCoreInstrumentation()
        .AddHttpClientInstrumentation()
        .AddRuntimeInstrumentation();
})
.WithTracing(tracing =>
{
    tracing
        .AddSource(builder.Environment.ApplicationName)
        // Duende IdentityServer trace sources
        .AddSource("Duende.IdentityServer")
        .AddSource("Duende.IdentityServer.Cache")
        .AddSource("Duende.IdentityServer.Services")
        .AddSource("Duende.IdentityServer.Stores")
        .AddSource("Duende.IdentityServer.Validation")
        .AddAspNetCoreInstrumentation()
        .AddHttpClientInstrumentation();
});
```

- Trace sources: `Duende.IdentityServer`, `.Cache`, `.Services`, `.Stores`, `.Validation`.
- Meter: `Duende.IdentityServer`.
- Don't use `IdentityServerConstants.Tracing.*` or `Telemetry.ServiceName` here; they'd require referencing `Duende.IdentityServer`. Only the IdentityServer project references that package.
