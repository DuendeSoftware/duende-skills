Add the IdentityServer trace sources and meter to `ConfigureOpenTelemetry` in your service defaults project's `Extensions.cs`. Use **string literals** for all names — never reference `IdentityServerConstants` or `Telemetry.ServiceName` from the shared project, because that would force a Duende.IdentityServer package reference into service defaults. Only the IdentityServer project should reference the Duende package.

## Tracing sources

```csharp
tracing
    .AddSource(builder.Environment.ApplicationName)
    // Duende IdentityServer trace sources
    .AddSource("Duende.IdentityServer")
    .AddSource("Duende.IdentityServer.Cache")
    .AddSource("Duende.IdentityServer.Services")
    .AddSource("Duende.IdentityServer.Stores")
    .AddSource("Duende.IdentityServer.Validation")
    .AddAspNetCoreInstrumentation()
    .AddHttpClientInstrumentation();
```

## Metrics

```csharp
metrics
    .AddMeter("Duende.IdentityServer")
    .AddAspNetCoreInstrumentation()
    .AddHttpClientInstrumentation()
    .AddRuntimeInstrumentation();
```

## Source/meter reference

| Kind | Name |
|------|------|
| Trace source (root) | `Duende.IdentityServer` |
| Trace source | `Duende.IdentityServer.Cache` |
| Trace source | `Duende.IdentityServer.Services` |
| Trace source | `Duende.IdentityServer.Stores` |
| Trace source | `Duende.IdentityServer.Validation` |
| Meter | `Duende.IdentityServer` |

Once these are registered, IdentityServer's spans (validation, store access, caching, service calls) and metrics will show up in the Aspire dashboard's traces and metrics views. Because they're plain strings, the service defaults project stays free of any Duende dependency.
