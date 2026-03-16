# Adding IdentityServer Telemetry to Aspire

To capture IdentityServer traces and metrics in the Aspire dashboard, you need to add the appropriate sources in your service defaults project.

## Tracing

```csharp
tracing
    .AddSource(builder.Environment.ApplicationName)
    .AddSource("Duende.IdentityServer")
    .AddAspNetCoreInstrumentation()
    .AddHttpClientInstrumentation();
```

## Metrics

```csharp
metrics
    .AddMeter("Duende.IdentityServer")
    .AddAspNetCoreInstrumentation()
    .AddHttpClientInstrumentation();
```

This will capture the main IdentityServer traces and metrics in the Aspire dashboard.
