# Adding OpenTelemetry to IdentityServer for Production Monitoring

## NuGet Packages Required

```bash
dotnet add package OpenTelemetry
dotnet add package OpenTelemetry.Extensions.Hosting
dotnet add package OpenTelemetry.Instrumentation.AspNetCore
dotnet add package OpenTelemetry.Exporter.Prometheus.AspNetCore
```

## Program.cs Configuration

```csharp
using Duende.IdentityServer;
using OpenTelemetry.Metrics;
using OpenTelemetry.Resources;
using OpenTelemetry.Trace;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddIdentityServer()
    .AddInMemoryIdentityResources(Config.IdentityResources)
    .AddInMemoryApiScopes(Config.ApiScopes)
    .AddInMemoryClients(Config.Clients);

// Configure OpenTelemetry
var openTelemetry = builder.Services.AddOpenTelemetry();

openTelemetry.ConfigureResource(r => r
    .AddService(builder.Environment.ApplicationName));

// Metrics with Prometheus exporter
openTelemetry.WithMetrics(m => m
    .AddMeter("Duende.IdentityServer")     // The IdentityServer meter (Telemetry.ServiceName)
    .AddAspNetCoreInstrumentation()
    .AddPrometheusExporter());

// Tracing — ONLY Basic source for production
openTelemetry.WithTracing(t => t
    .AddSource(IdentityServerConstants.Tracing.Basic)
    // Do NOT add these in production — too verbose:
    // .AddSource(IdentityServerConstants.Tracing.Stores)
    // .AddSource(IdentityServerConstants.Tracing.Validation)
    // .AddSource(IdentityServerConstants.Tracing.Cache)
    // .AddSource(IdentityServerConstants.Tracing.Services)
    .AddAspNetCoreInstrumentation()
    .AddOtlpExporter());    // Export traces to your collector

var app = builder.Build();

app.UseIdentityServer();

// Expose Prometheus scraping endpoint
app.UseOpenTelemetryPrometheusScrapingEndpoint();

app.MapGet("/", () => "IdentityServer is running");

app.Run();
```

## Key Configuration Decisions

### Meter Name

The IdentityServer meter is registered as `"Duende.IdentityServer"` (also available as `Telemetry.ServiceName`). This meter emits metrics like:

- `tokenservice.operation` — aggregated success/failure counts
- `active_requests` — current requests being processed
- `tokenservice.token_issued` — token issuance counts
- `tokenservice.client.secret_validation` — client auth success/failure

### Prometheus Exporter

`AddPrometheusExporter()` registers the Prometheus metrics exporter, and `UseOpenTelemetryPrometheusScrapingEndpoint()` maps the `/metrics` endpoint that Prometheus scrapes.

### Tracing Sources for Production

IdentityServer provides 5 tracing sources:

| Source | Content | Production? |
|--------|---------|-------------|
| `IdentityServerConstants.Tracing.Basic` | High-level request processing | **Yes** |
| `IdentityServerConstants.Tracing.Stores` | Database/store operations | No — too verbose |
| `IdentityServerConstants.Tracing.Validation` | Detailed validation | No — too verbose |
| `IdentityServerConstants.Tracing.Cache` | Cache operations | No — too verbose |
| `IdentityServerConstants.Tracing.Services` | Service-layer operations | No — too verbose |

For production, use **only `Basic`**. The other sources generate excessive trace data and are intended for development and troubleshooting. You can enable additional sources temporarily when diagnosing issues.
