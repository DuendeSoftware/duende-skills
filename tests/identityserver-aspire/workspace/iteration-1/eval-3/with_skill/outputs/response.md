# Adding IdentityServer Telemetry to Aspire Service Defaults

Add IdentityServer's trace sources and metrics to your service defaults project using **string literals only** — do NOT reference any Duende NuGet packages from the shared project.

## Tracing Configuration

In your service defaults `Extensions.cs`, add the IdentityServer activity sources:

```csharp
tracing
    .AddSource(builder.Environment.ApplicationName)
    // Duende IdentityServer trace sources (string literals — no Duende package reference)
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

## Why String Literals?

Using string literals instead of constants like `IdentityServerConstants.Tracing.Basic` or `Telemetry.ServiceName` avoids adding a `Duende.IdentityServer` package reference to the shared service defaults project. Only the IdentityServer project itself should reference the Duende package. The service defaults project is shared by all services in the solution.
