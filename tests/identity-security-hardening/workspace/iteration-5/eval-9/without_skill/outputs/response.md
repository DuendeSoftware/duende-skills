# Forwarding IdentityServer Events to Seq

You can build an audit trail using IdentityServer's event system and forward the events to Seq with a custom event sink.

## Enable events

IdentityServer won't emit events unless you turn them on, so enable the event categories in `AddIdentityServer`:

```csharp
builder.Services.AddIdentityServer(options =>
{
    options.Events.RaiseSuccessEvents = true;
    options.Events.RaiseFailureEvents = true;
    options.Events.RaiseErrorEvents = true;
    options.Events.RaiseInformationEvents = true;
})
// ...
```

This gives you success, failure, error, and informational events (logins, token issuance, consent, errors, etc.).

## Implement a custom event sink for Seq

Implement `IEventSink` and send the events to Seq. Since you already use Serilog, the simplest route is to log the event and configure the Serilog Seq sink, or you can POST directly to Seq's ingestion endpoint:

```csharp
using Duende.IdentityServer.Events;
using Duende.IdentityServer.Services;

public class SeqEventSink : IEventSink
{
    private readonly ILogger<SeqEventSink> _logger;
    public SeqEventSink(ILogger<SeqEventSink> logger) => _logger = logger;

    public Task PersistAsync(Event evt)
    {
        _logger.LogInformation("IdentityServer event {EventName} {@Event}", evt.Name, evt);
        return Task.CompletedTask;
    }
}

// Register the sink
builder.Services.AddTransient<IEventSink, SeqEventSink>();
```

Then add `Serilog.Sinks.Seq` and configure the Seq server URL in your Serilog config (or `appsettings.json`) so the logged events are shipped to Seq.

## Capture UI logins

Make sure success and failure events are enabled (above) so that login attempts are recorded in the audit trail, and confirm your login page surfaces the relevant events.

## Things to watch out for

- Enable the event flags — by default nothing is emitted.
- Events can contain PII (usernames, IP addresses), so make sure your Seq retention and access controls are appropriate.
- Keep the sink fast; if Seq is slow or down, don't block the request — buffer or send asynchronously.
- Add a `Retry-After`/queue mechanism if you expect high event volume.
