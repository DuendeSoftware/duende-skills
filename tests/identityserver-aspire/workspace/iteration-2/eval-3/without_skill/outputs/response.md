# Adding IdentityServer Telemetry to Aspire Service Defaults

To capture IdentityServer's OpenTelemetry data in the Aspire dashboard, you'll need to add the appropriate trace sources and meters.

## Tracing

IdentityServer likely exposes activity sources. You can add them in your service defaults project:

```csharp
tracing
    .AddSource(builder.Environment.ApplicationName)
    .AddSource("Duende.IdentityServer")
    .AddAspNetCoreInstrumentation()
    .AddHttpClientInstrumentation();
```

## Metrics

For metrics, try adding:

```csharp
metrics
    .AddMeter("Duende.IdentityServer")
    .AddAspNetCoreInstrumentation()
    .AddHttpClientInstrumentation();
```

## Notes

You might also want to check the Duende IdentityServer documentation for the exact source names they use. If the package exposes constants for these, you could reference them from the `Duende.IdentityServer` package:

```csharp
// If available, use the constants
using Duende.IdentityServer;

tracing
    .AddSource(IdentityServerConstants.Tracing.ServiceName);
```

However, you'll need to add a package reference to `Duende.IdentityServer` in the service defaults project to use these constants. Alternatively, just use the string literal `"Duende.IdentityServer"` to avoid the extra dependency.
