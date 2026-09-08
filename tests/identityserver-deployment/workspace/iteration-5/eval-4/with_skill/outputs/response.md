# OpenTelemetry for IdentityServer: Prometheus metrics + production tracing

IdentityServer emits traces and metrics through the standard .NET OpenTelemetry SDK. Below is a production-appropriate setup: Prometheus for metrics, distributed tracing with **only the `Basic` source** enabled (the other sources — Cache, Services, Stores, Validation — are verbose and meant for development/troubleshooting).

## 1. Add the NuGet packages

```bash
dotnet add package OpenTelemetry
dotnet add package OpenTelemetry.Extensions.Hosting
dotnet add package OpenTelemetry.Instrumentation.AspNetCore
dotnet add package OpenTelemetry.Exporter.Prometheus.AspNetCore
# (optional, for OTLP trace export to a collector/Jaeger/Tempo)
dotnet add package OpenTelemetry.Exporter.OpenTelemetryProtocol
```

## 2. Configure in Program.cs

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

// Correlate logs with traces (optional but recommended in .NET 8+)
builder.Logging.AddOpenTelemetry();

var otel = builder.Services.AddOpenTelemetry();

otel.ConfigureResource(r => r.AddService(builder.Environment.ApplicationName));

// ---- METRICS -> Prometheus ----
otel.WithMetrics(m => m
    .AddMeter("Duende.IdentityServer")   // == Telemetry.ServiceName
    .AddAspNetCoreInstrumentation()
    .AddPrometheusExporter());

// ---- TRACING -> production: Basic source ONLY ----
otel.WithTracing(t => t
    .AddSource(IdentityServerConstants.Tracing.Basic)   // high-level request processing only
    // Intentionally NOT adding Cache / Services / Stores / Validation in production
    .AddAspNetCoreInstrumentation()
    .AddOtlpExporter());                                  // export to your collector/Jaeger/Tempo

var app = builder.Build();

app.UseIdentityServer();

// Prometheus scraping endpoint (default /metrics)
app.UseOpenTelemetryPrometheusScrapingEndpoint();

app.MapGet("/", () => "IdentityServer is running");

app.Run();
```

## Why only `Basic` in production

IdentityServer exposes several trace sources:

| Source                                       | Traces                                   | Production? |
| -------------------------------------------- | ---------------------------------------- | ----------- |
| `IdentityServerConstants.Tracing.Basic`      | High-level request processing            | **Yes**     |
| `IdentityServerConstants.Tracing.Cache`      | Cache operations                         | No          |
| `IdentityServerConstants.Tracing.Services`   | Service-layer operations                 | No          |
| `IdentityServerConstants.Tracing.Stores`     | Store/database operations                | No          |
| `IdentityServerConstants.Tracing.Validation` | Detailed validation                      | No          |

Subscribing to `Stores`, `Validation`, etc. generates a large volume of spans and adds overhead. Start with `Basic`; temporarily add the others only when troubleshooting a specific issue.

## Metrics you'll get

With the `Duende.IdentityServer` meter you get counters such as `tokenservice.operation`, `tokenservice.token_issued`, `tokenservice.client.secret_validation`, `tokenservice.introspection`, `tokenservice.revocation`, and `active_requests` — ready to scrape from `/metrics` and chart/alert on in Prometheus/Grafana.

## Prometheus scrape config

```yaml
scrape_configs:
  - job_name: identityserver
    static_configs:
      - targets: ['identityserver:8080']
    metrics_path: /metrics
```
