# IdentityServer Events System with Seq Integration

## Enable All Event Categories

Configure IdentityServer to raise all event types:

```csharp
using Duende.IdentityServer;
using Microsoft.EntityFrameworkCore;
using Serilog;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddIdentityServer(options =>
{
    // Enable all four event categories for comprehensive auditing
    options.Events.RaiseSuccessEvents = true;
    options.Events.RaiseFailureEvents = true;
    options.Events.RaiseErrorEvents = true;
    options.Events.RaiseInformationEvents = true;
})
    .AddInMemoryIdentityResources(Config.IdentityResources)
    .AddInMemoryApiScopes(Config.ApiScopes)
    .AddInMemoryClients(Config.Clients);

// Register the custom event sink for Seq
builder.Services.AddTransient<Duende.IdentityServer.Services.IEventSink, SeqEventSink>();

var app = builder.Build();

app.UseIdentityServer();

app.MapGet("/", () => "IdentityServer is running");

app.Run();
```

## Custom IEventSink Implementation

```csharp
using Duende.IdentityServer.Events;
using Duende.IdentityServer.Services;
using Serilog;

public class SeqEventSink : IEventSink
{
    private readonly Serilog.ILogger _log;

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
        else
        {
            _log.Error("{Name} ({Id}), Details: {@details}",
                evt.Name, evt.Id, evt);
        }
        return Task.CompletedTask;
    }
}
```

## Key Points

- All four event categories must be enabled: `RaiseSuccessEvents`, `RaiseFailureEvents`, `RaiseErrorEvents`, and `RaiseInformationEvents`.
- The `IEventSink` interface has a single `PersistAsync(Event evt)` method.
- The custom event sink is registered in the DI container using `AddTransient<IEventSink, SeqEventSink>()`.
- Serilog's `WriteTo.Seq()` sends structured events to the Seq server with event name, id, and full details.
- Events work well with structured logging stores like Seq, ELK, or Splunk.

### Required NuGet Packages

```xml
<PackageReference Include="Serilog.Sinks.Seq" Version="7.0.0" />
<PackageReference Include="Serilog" Version="4.0.0" />
```
