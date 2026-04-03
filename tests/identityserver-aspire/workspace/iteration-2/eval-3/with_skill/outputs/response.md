# Adding IdentityServer OpenTelemetry Sources to Aspire Service Defaults

In your Aspire service defaults project's `Extensions.cs`, add the IdentityServer trace sources and meter as **string literals** — do NOT add any Duende NuGet package references to the service defaults project.

## Tracing Configuration

Add all five IdentityServer activity sources to your tracing setup:

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

## Metrics Configuration

Add the IdentityServer meter:

```csharp
metrics
    .AddMeter("Duende.IdentityServer")
    .AddAspNetCoreInstrumentation()
    .AddHttpClientInstrumentation()
    .AddRuntimeInstrumentation();
```

## Why string literals?

IdentityServer provides constants like `IdentityServerConstants.Tracing.Basic`, `IdentityServerConstants.Tracing.Cache`, etc. However, the service defaults project is shared across all projects in the Aspire solution. You should **not** add a `Duende.IdentityServer` package reference to the service defaults project — only the IdentityServer project itself should reference the Duende package.

Using string literals avoids this dependency while still capturing all the telemetry data.

## The five trace source names

| String literal | What it captures |
|---|---|
| `"Duende.IdentityServer"` | Core IdentityServer operations |
| `"Duende.IdentityServer.Cache"` | Caching operations |
| `"Duende.IdentityServer.Services"` | Service-level operations (token service, profile service, etc.) |
| `"Duende.IdentityServer.Stores"` | Store operations (configuration store, operational store, etc.) |
| `"Duende.IdentityServer.Validation"` | Validation operations (token validation, client validation, etc.) |

The meter name `"Duende.IdentityServer"` covers all IdentityServer metrics including token issuance counts, active sessions, and request durations.
