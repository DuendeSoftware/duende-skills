# Adding OpenTelemetry to IdentityServer

## Install Packages

```bash
dotnet add package OpenTelemetry.Extensions.Hosting
dotnet add package OpenTelemetry.Instrumentation.AspNetCore
dotnet add package OpenTelemetry.Exporter.Prometheus.AspNetCore
dotnet add package OpenTelemetry.Exporter.OpenTelemetryProtocol
```

## Configure OpenTelemetry

Update your `Program.cs`:

```csharp
using Duende.IdentityServer;
using Microsoft.EntityFrameworkCore;
using OpenTelemetry.Resources;

var builder = WebApplication.CreateBuilder(args);

var otel = builder.Services.AddOpenTelemetry();

otel.ConfigureResource(r => r
    .AddService(builder.Environment.ApplicationName));

// Metrics
otel.WithMetrics(m => m
    .AddAspNetCoreInstrumentation()
    .AddRuntimeInstrumentation()
    .AddPrometheusExporter());

// Tracing
otel.WithTracing(t => t
    .AddAspNetCoreInstrumentation()
    .AddHttpClientInstrumentation()
    .AddOtlpExporter());

builder.Services.AddIdentityServer()
    .AddInMemoryIdentityResources(Config.IdentityResources)
    .AddInMemoryApiScopes(Config.ApiScopes)
    .AddInMemoryClients(Config.Clients);

var app = builder.Build();

app.UseIdentityServer();

app.UseOpenTelemetryPrometheusScrapingEndpoint();

app.MapGet("/", () => "IdentityServer is running");

app.Run();
```

## Notes

- The `AddPrometheusExporter()` configures metrics to be exposed in Prometheus format
- `UseOpenTelemetryPrometheusScrapingEndpoint()` maps the `/metrics` endpoint for scraping
- `AddAspNetCoreInstrumentation()` captures HTTP request metrics and traces
- `AddOtlpExporter()` sends traces to an OpenTelemetry Collector via OTLP protocol
- For production, keep trace sampling reasonable to avoid excessive data volume

Configure Prometheus to scrape the `/metrics` endpoint at your service address.
