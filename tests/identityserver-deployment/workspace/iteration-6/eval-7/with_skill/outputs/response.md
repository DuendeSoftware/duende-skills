# Events → Seq

## Enable all categories

```csharp
builder.Services.AddIdentityServer(options =>
{
    options.Events.RaiseSuccessEvents = true;
    options.Events.RaiseFailureEvents = true;
    options.Events.RaiseErrorEvents = true;
    options.Events.RaiseInformationEvents = true;
})
.AddInMemoryIdentityResources(Config.IdentityResources)
.AddInMemoryApiScopes(Config.ApiScopes)
.AddInMemoryClients(Config.Clients);

builder.Services.AddTransient<IEventSink, SeqEventSink>();
```

## Custom sink (Serilog.Sinks.Seq)

```csharp
using Duende.IdentityServer.Events;
using Duende.IdentityServer.Services;
using Serilog;
using Serilog.Core;

public class SeqEventSink : IEventSink
{
    private readonly Logger _log;
    private readonly ILogger<SeqEventSink> _logger;

    public SeqEventSink(ILogger<SeqEventSink> logger)
    {
        _logger = logger;
        _log = new LoggerConfiguration()
            .WriteTo.Seq("http://localhost:5341")
            .CreateLogger();
    }

    public Task PersistAsync(Event evt)
    {
        if (evt.EventType == EventTypes.Success || evt.EventType == EventTypes.Information)
            _log.Information("{Name} ({Id}), Details: {@details}", evt.Name, evt.Id, evt);
        else
            _log.Error("{Name} ({Id}), Details: {@details}", evt.Name, evt.Id, evt);

        // custom sink replaces the default one: forward to ILogger if you still want them there
        _logger.LogInformation("{Name} ({Id})", evt.Name, evt.Id);
        return Task.CompletedTask;
    }
}
```

Important:
- **A custom `IEventSink` replaces the default sink.** Events no longer reach the standard ASP.NET Core logger unless your sink forwards them (as above) or fans out.
- For auditing, handle destination failures (Seq down) and restrict write/delete access to the audit store.
- Events contain user data — secure Seq accordingly.
- Raise your own events from UI code via `IEventService.RaiseAsync(new UserLoginSuccessEvent(...))` / `UserLoginFailureEvent`.
