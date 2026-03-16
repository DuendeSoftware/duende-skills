# Enabling IdentityServer Events and Writing to Seq

## Step 1: Enable Event Categories

IdentityServer supports four categories of events. Enable all of them for full audit coverage:

```csharp
builder.Services.AddIdentityServer(options =>
{
    options.Events.RaiseSuccessEvents = true;
    options.Events.RaiseFailureEvents = true;
    options.Events.RaiseErrorEvents = true;
    options.Events.RaiseInformationEvents = true;
});
```

## Step 2: Implement IEventSink for Seq

Create a custom event sink that sends events to Seq:

```bash
dotnet add package Serilog
dotnet add package Serilog.Sinks.Seq
```

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

## Step 3: Register in DI

```csharp
builder.Services.AddTransient<IEventSink, SeqEventSink>();
```

## Complete Example

```csharp
var builder = WebApplication.CreateBuilder(args);

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

var app = builder.Build();
app.UseIdentityServer();
app.Run();
```

This will send all IdentityServer events (login success/failure, token issuance, consent, errors) to your Seq server with structured data for easy querying.
