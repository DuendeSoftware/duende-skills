# Adding IdentityServer OpenTelemetry Sources to Aspire Service Defaults

In your service defaults project's `Extensions.cs` (or wherever `ConfigureOpenTelemetry` is defined), add the IdentityServer trace sources and meter as string literals:

## Tracing

```csharp
public static IHostApplicationBuilder ConfigureOpenTelemetry(this IHostApplicationBuilder builder)
{
    builder.Logging.AddOpenTelemetry(logging =>
    {
        logging.IncludeFormattedMessage = true;
        logging.IncludeScopes = true;
    });

    builder.Services.AddOpenTelemetry()
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
        })
        .WithMetrics(metrics =>
        {
            metrics
                .AddMeter(builder.Environment.ApplicationName)
                // Duende IdentityServer meter
                .AddMeter("Duende.IdentityServer")
                .AddAspNetCoreInstrumentation()
                .AddHttpClientInstrumentation()
                .AddRuntimeInstrumentation();
        });

    return builder;
}
```

## Source Names

### Trace sources (5 total):
| Source Name | What It Traces |
|---|---|
| `Duende.IdentityServer` | Core protocol processing |
| `Duende.IdentityServer.Cache` | Caching operations |
| `Duende.IdentityServer.Services` | Service-layer operations (token service, profile service, etc.) |
| `Duende.IdentityServer.Stores` | Store operations (client store, resource store, etc.) |
| `Duende.IdentityServer.Validation` | Request validation (token requests, authorize requests, etc.) |

### Meter (1):
| Meter Name | What It Measures |
|---|---|
| `Duende.IdentityServer` | Request counts, token issuance rates, validation results |

## Why String Literals?

All source and meter names are string literals, not constants like `IdentityServerConstants.Tracing.Basic` or `Telemetry.ServiceName`. This is intentional - the service defaults project is shared across all services in the solution, and only the IdentityServer project should reference the Duende.IdentityServer NuGet package. Using string literals avoids adding a Duende package dependency to the shared project.
