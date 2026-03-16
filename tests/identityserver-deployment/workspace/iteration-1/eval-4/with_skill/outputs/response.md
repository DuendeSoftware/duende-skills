# Adding OpenTelemetry to IdentityServer for Production Monitoring

## Step 1: Add Required NuGet Packages

```bash
dotnet add package OpenTelemetry
dotnet add package OpenTelemetry.Extensions.Hosting
dotnet add package OpenTelemetry.Instrumentation.AspNetCore
dotnet add package OpenTelemetry.Exporter.Prometheus.AspNetCore
dotnet add package OpenTelemetry.Exporter.OpenTelemetryProtocol
```

## Step 2: Configure OpenTelemetry in Program.cs

```csharp
using Duende.IdentityServer;
using Microsoft.EntityFrameworkCore;
using OpenTelemetry.Resources;

var builder = WebApplication.CreateBuilder(args);

// Add OpenTelemetry logging correlation
builder.Logging.AddOpenTelemetry();

// Configure OpenTelemetry
var openTelemetry = builder.Services.AddOpenTelemetry();

openTelemetry.ConfigureResource(r => r
    .AddService(builder.Environment.ApplicationName));

// Metrics: Add the Duende IdentityServer meter + Prometheus exporter
openTelemetry.WithMetrics(m => m
    .AddMeter("Duende.IdentityServer")   // This is Telemetry.ServiceName
    .AddAspNetCoreInstrumentation()
    .AddPrometheusExporter());

// Tracing: Only Basic source for production (not verbose sources)
openTelemetry.WithTracing(t => t
    .AddSource(IdentityServerConstants.Tracing.Basic)
    // DO NOT add these in production — they generate excessive trace data:
    // .AddSource(IdentityServerConstants.Tracing.Cache)
    // .AddSource(IdentityServerConstants.Tracing.Services)
    // .AddSource(IdentityServerConstants.Tracing.Stores)
    // .AddSource(IdentityServerConstants.Tracing.Validation)
    .AddAspNetCoreInstrumentation()
    .AddOtlpExporter());  // Send traces to your OTLP-compatible backend

builder.Services.AddIdentityServer()
    .AddInMemoryIdentityResources(Config.IdentityResources)
    .AddInMemoryApiScopes(Config.ApiScopes)
    .AddInMemoryClients(Config.Clients);

var app = builder.Build();

app.UseIdentityServer();

// Map Prometheus scraping endpoint
app.UseOpenTelemetryPrometheusScrapingEndpoint();

app.MapGet("/", () => "IdentityServer is running");

app.Run();
```

## Key Configuration Details

### Metrics

The IdentityServer meter name is `"Duende.IdentityServer"` (also available as `Telemetry.ServiceName`). This meter exposes counters for:

| Metric | Description |
|--------|-------------|
| `tokenservice.operation` | Aggregated success/failure/error counts |
| `active_requests` | Current requests being processed |
| `tokenservice.token_issued` | Token issuance attempts |
| `tokenservice.client.secret_validation` | Client authentication results |
| `tokenservice.introspection` | Token introspection counts |
| `tokenservice.revocation` | Token revocation counts |

The `AddPrometheusExporter()` makes these metrics available in Prometheus exposition format, and `UseOpenTelemetryPrometheusScrapingEndpoint()` maps the `/metrics` endpoint for Prometheus to scrape.

### Tracing Sources

IdentityServer provides five tracing sources with different verbosity levels:

| Source | What It Traces | Production? |
|--------|---------------|-------------|
| `IdentityServerConstants.Tracing.Basic` | High-level request processing | **Yes** |
| `IdentityServerConstants.Tracing.Cache` | Cache operations | No |
| `IdentityServerConstants.Tracing.Services` | Service-layer operations | No |
| `IdentityServerConstants.Tracing.Stores` | Store/database operations | No |
| `IdentityServerConstants.Tracing.Validation` | Detailed validation | No |

For production, **only subscribe to `Basic`**. The other sources generate excessive trace data that can overwhelm your tracing backend and increase costs. Add them temporarily when troubleshooting specific issues.

### Prometheus Scrape Configuration

Add this to your `prometheus.yml`:

```yaml
scrape_configs:
  - job_name: 'identityserver'
    scrape_interval: 15s
    static_configs:
      - targets: ['identityserver:8080']
```

## Verification

After deploying, verify metrics are available:

```bash
curl http://localhost:8080/metrics
```

You should see Prometheus-formatted metrics including the `Duende.IdentityServer` counters.
