# Enabling IdentityServer Events and Sending to Seq

## 1. Enable All Event Categories

```csharp
var builder = WebApplication.CreateBuilder(args);

builder.Services.AddIdentityServer(options =>
{
    // Enable all event categories for comprehensive auditing
    options.Events.RaiseSuccessEvents = true;
    options.Events.RaiseFailureEvents = true;
    options.Events.RaiseErrorEvents = true;
    options.Events.RaiseInformationEvents = true;
})
.AddInMemoryIdentityResources(Config.IdentityResources)
.AddInMemoryApiScopes(Config.ApiScopes)
.AddInMemoryClients(Config.Clients);

// Register the custom event sink
builder.Services.AddTransient<Duende.IdentityServer.Services.IEventSink, SeqEventSink>();

var app = builder.Build();

app.UseIdentityServer();

app.MapGet("/", () => "IdentityServer is running");

app.Run();
```

## 2. Implement the Custom IEventSink

```csharp
using Duende.IdentityServer.Events;
using Duende.IdentityServer.Services;
using Serilog;
using Serilog.Events;
using ILogger = Serilog.ILogger;

public class SeqEventSink : IEventSink
{
    private readonly ILogger _log;

    public SeqEventSink()
    {
        _log = new LoggerConfiguration()
            .MinimumLevel.Information()
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
        else
        {
            _log.Error("{Name} ({Id}), Details: {@details}",
                evt.Name, evt.Id, evt);
        }

        return Task.CompletedTask;
    }
}
```

## 3. Add NuGet Packages

```bash
dotnet add package Serilog
dotnet add package Serilog.Sinks.Seq
```

## How It Works

### Event Categories

IdentityServer supports four event categories:

| Property | What It Covers |
|----------|---------------|
| `RaiseSuccessEvents` | Successful authentication, token issuance, consent granted |
| `RaiseFailureEvents` | Failed authentication, invalid tokens, denied consent |
| `RaiseErrorEvents` | Unhandled exceptions, internal errors |
| `RaiseInformationEvents` | General operations, grants revoked |

By default, all are `false`. Enabling all four gives you comprehensive audit coverage.

### IEventSink

The `IEventSink` interface has a single method: `PersistAsync(Event evt)`. IdentityServer calls this for every raised event. The `Event` object contains:

- `Name` — event name (e.g., "Token Issued Success")
- `Id` — numeric event ID
- `EventType` — Success, Failure, Error, or Information
- `Category` — event category
- `ActivityId` — correlation ID for tracing
- Event-specific properties (client ID, scopes, etc.)

### DI Registration

Register the event sink as `IEventSink` in DI. IdentityServer resolves it automatically. You can register multiple sinks if needed — IdentityServer will call all of them.

### Seq Integration

The `{@details}` destructuring operator in Serilog sends the full event object as structured data to Seq, making all properties searchable. The `WriteTo.Seq()` sink sends events over HTTP to the Seq ingestion endpoint.
