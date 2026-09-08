# Adding OpenTelemetry (Prometheus metrics + tracing) to IdentityServer

You can wire up OpenTelemetry with the standard .NET OpenTelemetry packages. Below is a setup that exports metrics to Prometheus and enables distributed tracing.

## 1. NuGet packages

```bash
dotnet add package OpenTelemetry.Extensions.Hosting
dotnet add package OpenTelemetry.Instrumentation.AspNetCore
dotnet add package OpenTelemetry.Instrumentation.Http
dotnet add package OpenTelemetry.Exporter.Prometheus.AspNetCore
dotnet add package OpenTelemetry.Exporter.OpenTelemetryProtocol
```

## 2. Program.cs

```csharp
using OpenTelemetry.Metrics;
using OpenTelemetry.Resources;
using OpenTelemetry.Trace;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddIdentityServer()
    .AddInMemoryIdentityResources(Config.IdentityResources)
    .AddInMemoryApiScopes(Config.ApiScopes)
    .AddInMemoryClients(Config.Clients);

builder.Services.AddOpenTelemetry()
    .ConfigureResource(r => r.AddService(
        serviceName: builder.Environment.ApplicationName))
    .WithMetrics(metrics => metrics
        .AddAspNetCoreInstrumentation()
        .AddHttpClientInstrumentation()
        .AddRuntimeInstrumentation()
        .AddMeter("Duende.IdentityServer")   // IdentityServer's meter
        .AddPrometheusExporter())
    .WithTracing(tracing => tracing
        .AddAspNetCoreInstrumentation()
        .AddHttpClientInstrumentation()
        .AddSource("Duende.IdentityServer")  // IdentityServer activity source
        .AddOtlpExporter());                 // send traces to your collector

var app = builder.Build();

app.UseIdentityServer();

// Prometheus scrape endpoint at /metrics
app.UseOpenTelemetryPrometheusScrapingEndpoint();

app.MapGet("/", () => "IdentityServer is running");

app.Run();
```

## 3. Metrics vs tracing

- **Metrics** are exported in Prometheus format at `/metrics` via `AddPrometheusExporter()` + `UseOpenTelemetryPrometheusScrapingEndpoint()`. Point your Prometheus server at that path.
- **Tracing** is exported over OTLP to a collector (Jaeger, Tempo, etc.). ASP.NET Core instrumentation captures incoming request spans; adding the IdentityServer activity source captures its internal spans.

## 4. Keep tracing lean in production

Distributed tracing can get noisy. For production I'd recommend sampling to keep volume/cost down, e.g. a parent-based ratio sampler:

```csharp
.WithTracing(tracing => tracing
    .SetSampler(new ParentBasedSampler(new TraceIdRatioBasedSampler(0.1))) // 10%
    .AddAspNetCoreInstrumentation()
    .AddSource("Duende.IdentityServer")
    .AddOtlpExporter());
```

Enable full/verbose tracing only temporarily when you're debugging a specific problem.

## 5. Prometheus scrape config

```yaml
scrape_configs:
  - job_name: 'identityserver'
    metrics_path: /metrics
    static_configs:
      - targets: ['identityserver:8080']
```

That gives you Prometheus metrics plus distributed traces for production monitoring.
