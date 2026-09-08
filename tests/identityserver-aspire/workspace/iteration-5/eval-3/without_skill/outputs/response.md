You can wire IdentityServer's OpenTelemetry signals into your service defaults project by registering its activity source and meter in `ConfigureOpenTelemetry`. To keep the service defaults project dependency-free, use plain string names rather than importing any Duende constant (which would drag a Duende.IdentityServer package reference into the shared project).

## Tracing

Duende IdentityServer publishes its activities under the `Duende.IdentityServer` namespace, so add that as a source:

```csharp
tracing
    .AddSource(builder.Environment.ApplicationName)
    .AddSource("Duende.IdentityServer")
    .AddAspNetCoreInstrumentation()
    .AddHttpClientInstrumentation();
```

## Metrics

The meter is likewise published under `Duende.IdentityServer`:

```csharp
metrics
    .AddMeter("Duende.IdentityServer")
    .AddAspNetCoreInstrumentation()
    .AddHttpClientInstrumentation()
    .AddRuntimeInstrumentation();
```

## Notes

- All names above are string literals, so the shared service defaults project takes **no** dependency on any Duende NuGet package — only the IdentityServer project itself references Duende.
- IdentityServer may also emit spans under more specific sub-namespaces (for example nested activity sources for stores or validation). If you find spans missing in the Aspire dashboard, check IdentityServer's telemetry documentation for the exact sub-source names and add each one with an additional `.AddSource("...")` call. Since `AddSource`/`AddMeter` don't support wildcards, every source name has to be listed explicitly.

After registering these, IdentityServer traces and metrics will surface in the Aspire dashboard alongside your other services.
