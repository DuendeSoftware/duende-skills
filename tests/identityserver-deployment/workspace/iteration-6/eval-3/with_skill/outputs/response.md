# Health checks for Kubernetes

Use a **liveness** probe (pipeline responds, no dependency checks) and a **readiness** probe (tagged DB checks). Avoid custom `IHealthCheck` classes calling discovery endpoint handlers.

Package: `Microsoft.Extensions.Diagnostics.HealthChecks.EntityFrameworkCore`.

```csharp
builder.Services.AddIdentityServer()
    .AddConfigurationStore(o => o.ConfigureDbContext = b => b.UseSqlServer(cs))
    .AddOperationalStore(o => o.ConfigureDbContext = b => b.UseSqlServer(cs));

builder.Services.AddHealthChecks()
    .AddDbContextCheck<ConfigurationDbContext>(tags: ["db", "ready"])
    .AddDbContextCheck<PersistedGrantDbContext>(tags: ["db", "ready"]);

var app = builder.Build();

app.UseIdentityServer();

// Liveness: runs no checks, only proves the pipeline responds
app.MapHealthChecks("/health/live", new() { Predicate = _ => false });
// Readiness: configuration + operational stores
app.MapHealthChecks("/health/ready", new() { Predicate = x => x.Tags.Contains("ready") });
```

Kubernetes:

```yaml
livenessProbe:
  httpGet: { path: /health/live, port: 5000 }
readinessProbe:
  httpGet: { path: /health/ready, port: 5000 }
```

Dockerfile:

```dockerfile
HEALTHCHECK CMD curl --fail http://localhost:5000/health/live || exit 1
```
(curl must exist in the image; Kubernetes ignores HEALTHCHECK and uses its probes.)

Tags let you add more endpoints (e.g. signing key store). Liveness deliberately excludes the DB so a DB outage makes pods unready, not restarted.
