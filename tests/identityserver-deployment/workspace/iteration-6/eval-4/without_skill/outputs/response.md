# OpenTelemetry for IdentityServer

Packages: `OpenTelemetry.Extensions.Hosting`, `OpenTelemetry.Exporter.Prometheus.AspNetCore` (prerelease), `OpenTelemetry.Instrumentation.AspNetCore`, `OpenTelemetry.Instrumentation.Http`, `OpenTelemetry.Exporter.OpenTelemetryProtocol`.

```csharp
using OpenTelemetry.Metrics;
using OpenTelemetry.Resources;
using OpenTelemetry.Trace;

builder.Services.AddOpenTelemetry()
    .ConfigureResource(r => r.AddService("IdentityServer"))
    .WithMetrics(m => m
        .AddAspNetCoreInstrumentation()
        .AddHttpClientInstrumentation()
        .AddMeter("Duende.IdentityServer")
        .AddPrometheusExporter())
    .WithTracing(t => t
        .AddAspNetCoreInstrumentation()
        .AddHttpClientInstrumentation()
        .AddSource("Duende.IdentityServer")   // core tracing source
        .AddOtlpExporter());

var app = builder.Build();
app.UseIdentityServer();
app.MapPrometheusScrapingEndpoint();   // /metrics
```

Production guidance: Duende exposes extra, more verbose activity sources (e.g. stores, validation, services, caches). Those produce high volume and detail, so leave them off in production and enable them only when debugging. Stick to the main `Duende.IdentityServer` source plus ASP.NET Core and HttpClient instrumentation. Add `Microsoft.EntityFrameworkCore`/SqlClient instrumentation only if you need it, and sample (e.g. `TraceIdRatioBasedSampler`). Protect `/metrics` (network policy or `.RequireHost`) so it isn't public.

prometheus.yml:
```yaml
scrape_configs:
  - job_name: identityserver
    metrics_path: /metrics
    static_configs: [{ targets: ["identityserver:8080"] }]
```
