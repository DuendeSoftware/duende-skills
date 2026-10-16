# Health checks for IdentityServer

```csharp
builder.Services.AddIdentityServer()
    .AddConfigurationStore(o => o.ConfigureDbContext = b => b.UseSqlServer(cs))
    .AddOperationalStore(o => o.ConfigureDbContext = b => b.UseSqlServer(cs));

builder.Services.AddHealthChecks()
    .AddCheck("self", () => HealthCheckResult.Healthy(), tags: new[] { "live" })
    .AddDbContextCheck<ConfigurationDbContext>("config-db", tags: new[] { "ready" })
    .AddDbContextCheck<PersistedGrantDbContext>("operational-db", tags: new[] { "ready" });

var app = builder.Build();

app.UseIdentityServer();

app.MapHealthChecks("/health/live", new HealthCheckOptions
{
    Predicate = c => c.Tags.Contains("live")
});
app.MapHealthChecks("/health/ready", new HealthCheckOptions
{
    Predicate = c => c.Tags.Contains("ready")
});
```
Package: `Microsoft.Extensions.Diagnostics.HealthChecks.EntityFrameworkCore`. Namespaces: `Microsoft.Extensions.Diagnostics.HealthChecks`, `Microsoft.AspNetCore.Diagnostics.HealthChecks`.

Liveness should not touch the DB (a DB outage would restart all pods pointlessly); readiness does.

Kubernetes:
```yaml
livenessProbe:
  httpGet: { path: /health/live, port: 8080 }
  periodSeconds: 10
readinessProbe:
  httpGet: { path: /health/ready, port: 8080 }
  periodSeconds: 10
```

Dockerfile (needs curl in the image; the aspnet runtime images don't include it):
```dockerfile
RUN apt-get update && apt-get install -y --no-install-recommends curl && rm -rf /var/lib/apt/lists/*
HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=3 \
  CMD curl -f http://localhost:8080/health/live || exit 1
```
In Kubernetes the Dockerfile HEALTHCHECK is ignored; probes are used instead. Consider not exposing the health endpoints publicly through your ingress.
