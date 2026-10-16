# Audit trail: IdentityServer events → Seq

## 1. Enable events
```csharp
builder.Services.AddIdentityServer(options =>
{
    options.Events.RaiseSuccessEvents = true;
    options.Events.RaiseFailureEvents = true;
    options.Events.RaiseErrorEvents = true;
    options.Events.RaiseInformationEvents = true;
});
```

## 2. Serilog → Seq
```
dotnet add package Serilog.Sinks.Seq
```
```csharp
builder.Host.UseSerilog((ctx, lc) => lc
    .MinimumLevel.Information()
    .MinimumLevel.Override("Microsoft", Serilog.Events.LogEventLevel.Warning)
    .Enrich.FromLogContext()
    .WriteTo.Console()
    .WriteTo.Seq(ctx.Configuration["Seq:Url"]!, apiKey: ctx.Configuration["Seq:ApiKey"])
    .ReadFrom.Configuration(ctx.Configuration));
```

## 3. Custom event sink
```csharp
using Duende.IdentityServer.Events;
using Duende.IdentityServer.Services;

public class SeqAuditEventSink : IEventSink
{
    private readonly ILogger<SeqAuditEventSink> _logger;
    public SeqAuditEventSink(ILogger<SeqAuditEventSink> logger) => _logger = logger;

    public Task PersistAsync(Event evt)
    {
        switch (evt)
        {
            case UserLoginSuccessEvent s:
                _logger.LogInformation("AUDIT {EventName} user={Username} subject={SubjectId} client={ClientId}",
                    s.Name, s.Username, s.SubjectId, s.ClientId);
                break;
            case UserLoginFailureEvent f:
                _logger.LogWarning("AUDIT {EventName} user={Username} client={ClientId} message={Message}",
                    f.Name, f.Username, f.ClientId, f.Message);
                break;
            default:
                _logger.LogInformation("AUDIT {EventName} {@Event}", evt.Name, evt);
                break;
        }
        return Task.CompletedTask;
    }
}

builder.Services.AddTransient<IEventSink, SeqAuditEventSink>();
```
Register it **after** `AddIdentityServer()` so it replaces the default sink.

## 4. UI logins
Events for your own login page are **not raised automatically**, since the login UI is your code. In the Razor page, inject `IEventService`:

```csharp
// success
await _events.RaiseAsync(new UserLoginSuccessEvent(user.Username, user.SubjectId, user.Username, clientId: context?.Client.ClientId));
// failure
await _events.RaiseAsync(new UserLoginFailureEvent(Input.Username, "invalid credentials", clientId: context?.Client.ClientId));
```

## Things you might miss
- Raising failure/success events flags must be enabled or they're swallowed.
- Don't log passwords, tokens, or PII beyond what you need; mind GDPR retention.
- Protect Seq with API keys/TLS; use separate ingest keys; set retention.
- Under load, the sink is called inline: keep it fast (Serilog's Seq sink batches asynchronously).
- Log the client IP (behind a proxy, requires forwarded headers).
- Add alerts in Seq for bursts of `UserLoginFailure`.
- Use `Log.CloseAndFlush()` on shutdown so events aren't lost.
- Tamper-resistance: audit logs should go to append-only storage too.
