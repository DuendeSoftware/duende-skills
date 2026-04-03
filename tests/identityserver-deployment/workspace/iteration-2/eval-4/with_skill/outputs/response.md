# OpenTelemetry for Production IdentityServer

## NuGet Packages

Add these packages to your project:

```bash
dotnet add package OpenTelemetry
dotnet add package OpenTelemetry.Extensions.Hosting
dotnet add package OpenTelemetry.Instrumentation.AspNetCore
dotnet add package OpenTelemetry.Exporter.OpenTelemetryProtocol
dotnet add package OpenTelemetry.Exporter.Prometheus.AspNetCore
```

## Updated Program.cs

```csharp
using Duende.IdentityServer;
using Microsoft.EntityFrameworkCore;
using OpenTelemetry.Resources;

var builder = WebApplication.CreateBuilder(args);

// Add OpenTelemetry logging to correlate logs with traces
builder.Logging.AddOpenTelemetry();

var openTelemetry = builder.Services.AddOpenTelemetry();

openTelemetry.ConfigureResource(r => r
    .AddService(builder.Environment.ApplicationName));

// Configure metrics with Prometheus exporter
openTelemetry.WithMetrics(m => m
    .AddMeter("Duende.IdentityServer")   // Telemetry.ServiceName == "Duende.IdentityServer"
    .AddPrometheusExporter());

// Configure tracing — only Basic for production (not verbose sources)
openTelemetry.WithTracing(t => t
    .AddSource(IdentityServerConstants.Tracing.Basic)
    // DO NOT add in production — these are verbose:
    // .AddSource(IdentityServerConstants.Tracing.Cache)
    // .AddSource(IdentityServerConstants.Tracing.Services)
    // .AddSource(IdentityServerConstants.Tracing.Stores)
    // .AddSource(IdentityServerConstants.Tracing.Validation)
    .AddAspNetCoreInstrumentation()
    .AddOtlpExporter());  // Export traces to an OTLP collector

builder.Services.AddIdentityServer()
    .AddInMemoryIdentityResources(Config.IdentityResources)
    .AddInMemoryApiScopes(Config.ApiScopes)
    .AddInMemoryClients(Config.Clients);

var app = builder.Build();

// Add Prometheus scraping endpoint
app.UseOpenTelemetryPrometheusScrapingEndpoint();

app.UseIdentityServer();

app.MapGet("/", () => "IdentityServer is running");

app.Run();
```

## Key Points

- The meter name is `"Duende.IdentityServer"` (also accessible as `Telemetry.ServiceName`). This emits metrics like `tokenservice.operation`, `active_requests`, `tokenservice.token_issued`, etc.
- **For production**, only add `IdentityServerConstants.Tracing.Basic` as the tracing source. This covers high-level request processing. The other sources (`Stores`, `Validation`, `Cache`, `Services`) generate excessive trace data in production and should only be enabled for troubleshooting.
- `AddPrometheusExporter()` on the metrics configuration and `UseOpenTelemetryPrometheusScrapingEndpoint()` in the pipeline expose a `/metrics` endpoint for Prometheus to scrape.
