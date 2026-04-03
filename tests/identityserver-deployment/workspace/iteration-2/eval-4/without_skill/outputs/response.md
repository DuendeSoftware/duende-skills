# OpenTelemetry for IdentityServer

## NuGet Packages

```bash
dotnet add package OpenTelemetry.Extensions.Hosting
dotnet add package OpenTelemetry.Instrumentation.AspNetCore
dotnet add package OpenTelemetry.Exporter.Prometheus.AspNetCore
dotnet add package OpenTelemetry.Exporter.OpenTelemetryProtocol
```

## Updated Program.cs

```csharp
using OpenTelemetry.Resources;

var builder = WebApplication.CreateBuilder(args);

var openTelemetry = builder.Services.AddOpenTelemetry();

openTelemetry.ConfigureResource(r => r
    .AddService("IdentityServer"));

openTelemetry.WithMetrics(m => m
    .AddAspNetCoreInstrumentation()
    .AddPrometheusExporter());

openTelemetry.WithTracing(t => t
    .AddAspNetCoreInstrumentation()
    .AddOtlpExporter());

builder.Services.AddIdentityServer()
    .AddInMemoryIdentityResources(Config.IdentityResources)
    .AddInMemoryApiScopes(Config.ApiScopes)
    .AddInMemoryClients(Config.Clients);

var app = builder.Build();

app.UseOpenTelemetryPrometheusScrapingEndpoint();
app.UseIdentityServer();

app.MapGet("/", () => "IdentityServer is running");

app.Run();
```

This sets up basic OpenTelemetry with Prometheus for metrics and OTLP for distributed tracing. You'll need to configure your Prometheus server to scrape the `/metrics` endpoint.
