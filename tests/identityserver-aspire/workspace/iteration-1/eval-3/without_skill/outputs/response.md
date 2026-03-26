# Adding IdentityServer Telemetry to Aspire

To see IdentityServer traces and metrics in the Aspire dashboard, you need to register the appropriate sources. In your service defaults project:

```csharp
public static IHostApplicationBuilder ConfigureOpenTelemetry(this IHostApplicationBuilder builder)
{
    builder.Services.AddOpenTelemetry()
        .WithTracing(tracing =>
        {
            tracing
                .AddSource(builder.Environment.ApplicationName)
                .AddSource("Duende.IdentityServer")
                .AddAspNetCoreInstrumentation()
                .AddHttpClientInstrumentation();
        })
        .WithMetrics(metrics =>
        {
            metrics
                .AddMeter(builder.Environment.ApplicationName)
                .AddMeter("Duende.IdentityServer")
                .AddAspNetCoreInstrumentation()
                .AddHttpClientInstrumentation()
                .AddRuntimeInstrumentation();
        });

    return builder;
}
```

This adds the main `Duende.IdentityServer` trace source and meter. The Aspire dashboard will now show IdentityServer traces alongside your other services.
