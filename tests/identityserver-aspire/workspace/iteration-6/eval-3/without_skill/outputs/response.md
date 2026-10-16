In `ServiceDefaults/Extensions.cs`, use string names only, so no Duende package reference is needed:

```csharp
builder.Services.AddOpenTelemetry()
    .WithMetrics(metrics =>
    {
        metrics.AddAspNetCoreInstrumentation()
               .AddHttpClientInstrumentation()
               .AddRuntimeInstrumentation()
               .AddMeter("Duende.IdentityServer");
    })
    .WithTracing(tracing =>
    {
        tracing.AddSource(builder.Environment.ApplicationName)
               .AddSource("Duende.IdentityServer")
               .AddAspNetCoreInstrumentation()
               .AddHttpClientInstrumentation();
    });
```

Trace source: `Duende.IdentityServer` (IdentityServer also has more specific sources in newer versions, e.g. `Duende.IdentityServer.Stores`, `Duende.IdentityServer.Services`, `Duende.IdentityServer.Validation`). Meter: `Duende.IdentityServer`. `AddSource`/`AddMeter` take strings, so the service defaults project stays free of Duende dependencies. Also enable it in IdentityServer with `options.Telemetry` as needed.
