# IdentityServer Events with Seq

## Enable Events

```csharp
builder.Services.AddIdentityServer(options =>
{
    options.Events.RaiseSuccessEvents = true;
    options.Events.RaiseFailureEvents = true;
    options.Events.RaiseErrorEvents = true;
    options.Events.RaiseInformationEvents = true;
});
```

## Create Event Sink

```csharp
using Duende.IdentityServer.Events;
using Duende.IdentityServer.Services;

public class SeqEventSink : IEventSink
{
    private readonly Serilog.ILogger _logger;

    public SeqEventSink()
    {
        _logger = new Serilog.LoggerConfiguration()
            .WriteTo.Seq("http://localhost:5341")
            .CreateLogger();
    }

    public Task PersistAsync(Event evt)
    {
        _logger.Information("IdentityServer Event: {EventName} ({EventId}): {@Event}",
            evt.Name, evt.Id, evt);
        return Task.CompletedTask;
    }
}
```

## Register

```csharp
builder.Services.AddSingleton<IEventSink, SeqEventSink>();
```

This sends all IdentityServer events to your Seq server with structured data.
