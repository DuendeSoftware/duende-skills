# Adding OpenTelemetry to IdentityServer

## Packages

```bash
dotnet add package OpenTelemetry.Extensions.Hosting
dotnet add package OpenTelemetry.Instrumentation.AspNetCore
dotnet add package OpenTelemetry.Exporter.Prometheus.AspNetCore
```

## Configuration

```csharp
using OpenTelemetry.Metrics;
using OpenTelemetry.Trace;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddIdentityServer()
    .AddInMemoryIdentityResources(Config.IdentityResources)
    .AddInMemoryApiScopes(Config.ApiScopes)
    .AddInMemoryClients(Config.Clients);

builder.Services.AddOpenTelemetry()
    .WithMetrics(m => m
        .AddAspNetCoreInstrumentation()
        .AddPrometheusExporter())
    .WithTracing(t => t
        .AddAspNetCoreInstrumentation()
        .AddSource("Duende.IdentityServer")
        .AddOtlpExporter());

var app = builder.Build();

app.UseIdentityServer();
app.UseOpenTelemetryPrometheusScrapingEndpoint();

app.Run();
```

This adds ASP.NET Core metrics with Prometheus export and distributed tracing for your IdentityServer.
