# OpenTelemetry (Prometheus + production tracing)

```bash
dotnet add package OpenTelemetry
dotnet add package OpenTelemetry.Extensions.Hosting
dotnet add package OpenTelemetry.Instrumentation.AspNetCore
dotnet add package OpenTelemetry.Exporter.OpenTelemetryProtocol
dotnet add package OpenTelemetry.Exporter.Prometheus.AspNetCore --prerelease
```

```csharp
using Duende.IdentityServer;
using OpenTelemetry.Resources;

builder.Logging.AddOpenTelemetry();   // correlate logs with traces

var openTelemetry = builder.Services.AddOpenTelemetry();

openTelemetry.ConfigureResource(r => r.AddService(builder.Environment.ApplicationName));

openTelemetry.WithMetrics(m => m
    .AddMeter("Duende.IdentityServer")   // Telemetry.ServiceName
    .AddPrometheusExporter());

openTelemetry.WithTracing(t => t
    .AddSource(IdentityServerConstants.Tracing.Basic)   // production-appropriate only
    .AddAspNetCoreInstrumentation()
    .AddOtlpExporter());

var app = builder.Build();
app.UseIdentityServer();
app.UseOpenTelemetryPrometheusScrapingEndpoint();   // /metrics
```

## Why only `Basic`
Other sources — `Tracing.Cache`, `Tracing.Services`, `Tracing.Stores`, `Tracing.Validation` — are verbose (cache ops, DB calls, detailed validation) and generate excessive trace data. Add them temporarily when troubleshooting, or in development.

## Key metrics (meter `Duende.IdentityServer`)
`tokenservice.operation`, `active_requests`, `tokenservice.token_issued`, `tokenservice.client.secret_validation`, `tokenservice.introspection`, `tokenservice.revocation`, plus UI metrics `tokenservice.user_login`, `user_logout`, `tokenservice.consent` if you instrument your UI.

Prometheus scrape config targets `/metrics`; restrict access to it at the network level.
