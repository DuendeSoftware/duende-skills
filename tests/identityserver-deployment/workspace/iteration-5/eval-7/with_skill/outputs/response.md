# Enabling IdentityServer events and forwarding them to Seq

IdentityServer's **events** system emits higher-level, structured records (login success/failure, token issued, consent, etc.) that are ideal for auditing. You enable the event categories on the IdentityServer options and implement an `IEventSink` to route them wherever you like — here, Seq.

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

Those four flags — `RaiseSuccessEvents`, `RaiseFailureEvents`, `RaiseErrorEvents`, `RaiseInformationEvents` — cover every event category. For auditing you want them all on.

## 2. Implement a custom IEventSink that writes to Seq

`IEventSink` has a single method, `PersistAsync(Event evt)`, called for every raised event. Use Serilog's Seq sink and log with structured properties so the event name, id, and full details are queryable in Seq:

```csharp
using Duende.IdentityServer.Events;
using Duende.IdentityServer.Services;
using Serilog;
using ILogger = Serilog.ILogger;

public class SeqEventSink : IEventSink
{
    private readonly ILogger _log;

    public SeqEventSink()
    {
        _log = new LoggerConfiguration()
            .WriteTo.Seq("http://localhost:5341")
            .CreateLogger();
    }

    public Task PersistAsync(Event evt)
    {
        if (evt.EventType == EventTypes.Success ||
            evt.EventType == EventTypes.Information)
        {
            _log.Information("{Name} ({Id}), Details: {@details}",
                evt.Name, evt.Id, evt);
        }
        else // Failure / Error
        {
            _log.Error("{Name} ({Id}), Details: {@details}",
                evt.Name, evt.Id, evt);
        }

        return Task.CompletedTask;
    }
}
```

Logging the whole `evt` object with the `{@details}` destructuring operator gives Seq the structured payload (subject, client, endpoint, category, etc.), while `{Name}` and `{Id}` are first-class searchable fields.

## 3. Register the sink in DI

IdentityServer resolves `IEventSink` from the container, so register yours:

```csharp
builder.Services.AddTransient<IEventSink, SeqEventSink>();
```

Add this alongside your `AddIdentityServer(...)` registration.

## Important: you're replacing the default sink

IdentityServer ships with a **default `IEventSink` that writes events to the ASP.NET Core `ILogger`**. When you register your own `SeqEventSink`, it **replaces** that default — events will no longer be written to the standard logger automatically. If you still want them in your normal logging pipeline in addition to Seq, forward them yourself inside `PersistAsync` (e.g. also inject and call an `ILogger<SeqEventSink>`), or configure Serilog as your app-wide logging provider so both paths converge.

## Result

With all four categories enabled and `SeqEventSink` registered, every IdentityServer event flows to Seq as structured, searchable audit data. Seq (like ELK or Splunk) is a great fit because the `{@details}` payload is fully queryable.
