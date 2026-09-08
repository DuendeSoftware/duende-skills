# Enabling IdentityServer events and sending them to Seq

IdentityServer has a built-in **events** system that produces structured records for things like login success/failure, token issuance, and consent. You turn on the categories in options and implement `IEventSink` to route them to your audit store — in this case Seq.

## 1. Enable all event categories

```csharp
// Program.cs
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
```

Setting all four `Raise*Events` flags to `true` emits every category, which is what you want for full auditing.

## 2. Configure Serilog with the Seq sink

Add the Serilog packages (`Serilog.AspNetCore`, `Serilog.Sinks.Seq`) and point Serilog at your Seq server:

```csharp
using Serilog;

Log.Logger = new LoggerConfiguration()
    .MinimumLevel.Information()
    .WriteTo.Console()
    .WriteTo.Seq("http://localhost:5341")
    .CreateLogger();

builder.Host.UseSerilog();
```

## 3. Implement a custom IEventSink

`IEventSink` requires a single `PersistAsync(Event evt)` method. Write the event to Seq via `ILogger` with structured properties so the name, id, and details are searchable:

```csharp
using Duende.IdentityServer.Events;
using Duende.IdentityServer.Services;

public class SeqEventSink : IEventSink
{
    private readonly ILogger<SeqEventSink> _logger;

    public SeqEventSink(ILogger<SeqEventSink> logger) => _logger = logger;

    public Task PersistAsync(Event evt)
    {
        if (evt.EventType == EventTypes.Success ||
            evt.EventType == EventTypes.Information)
        {
            _logger.LogInformation("IdentityServer Event {EventName} ({EventId}): {@Event}",
                evt.Name, evt.Id, evt);
        }
        else
        {
            _logger.LogError("IdentityServer Event {EventName} ({EventId}): {@Event}",
                evt.Name, evt.Id, evt);
        }

        return Task.CompletedTask;
    }
}
```

Because Serilog is the logging provider (step 2), these `ILogger` calls are written to Seq. The `{@Event}` destructuring captures the full structured payload; `{EventName}` and `{EventId}` become queryable fields in Seq.

## 4. Register the sink

```csharp
builder.Services.AddTransient<IEventSink, SeqEventSink>();
```

## Result

Every IdentityServer event (success, failure, error, information) is now captured and shipped to Seq as structured, searchable audit data. You can build Seq queries/alerts on properties like `EventName`, client id, or subject.
