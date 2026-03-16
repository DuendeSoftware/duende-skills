# Enabling IdentityServer Events and Sending to Seq

## Step 1: Enable All Event Categories

IdentityServer has four event categories that can be individually enabled. For comprehensive auditing, enable all of them:

```csharp
using Duende.IdentityServer;
using Microsoft.EntityFrameworkCore;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddIdentityServer(options =>
{
    // Enable all event categories for auditing
    options.Events.RaiseSuccessEvents = true;
    options.Events.RaiseFailureEvents = true;
    options.Events.RaiseErrorEvents = true;
    options.Events.RaiseInformationEvents = true;
})
    .AddInMemoryIdentityResources(Config.IdentityResources)
    .AddInMemoryApiScopes(Config.ApiScopes)
    .AddInMemoryClients(Config.Clients);
```

## Step 2: Create a Custom IEventSink for Seq

IdentityServer raises events through the `IEventSink` interface. Implement a custom sink that writes events to your Seq server using Serilog:

### Add NuGet Packages

```bash
dotnet add package Serilog
dotnet add package Serilog.Sinks.Seq
```

### Implement the Event Sink

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
            .WriteTo.Seq("http://localhost:5341")  // Your Seq server URL
            .Enrich.WithProperty("Application", "IdentityServer")
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

## Step 3: Register the Event Sink

Register your custom event sink in the DI container so IdentityServer uses it:

```csharp
// After AddIdentityServer()
builder.Services.AddTransient<IEventSink, SeqEventSink>();
```

## Complete Program.cs

```csharp
using Duende.IdentityServer;
using Duende.IdentityServer.Services;
using Microsoft.EntityFrameworkCore;

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

// Register custom event sink for Seq
builder.Services.AddTransient<IEventSink, SeqEventSink>();

var app = builder.Build();

app.UseIdentityServer();

app.MapGet("/", () => "IdentityServer is running");

app.Run();
```

## What Events You'll See in Seq

With all event categories enabled, you'll receive structured events including:

- **Success events**: `TokenIssuedSuccessEvent`, `UserLoginSuccessEvent`, `ConsentGrantedEvent`
- **Failure events**: `UserLoginFailureEvent`, `ClientAuthenticationFailureEvent`, `TokenIssuedFailureEvent`
- **Error events**: `UnhandledExceptionEvent`, various internal error events
- **Information events**: `TokenRevokedSuccessEvent`, `DeviceAuthorizationSuccessEvent`

Each event contains structured data with the event name, ID, timestamp, category, and event-specific details — making them easy to query and filter in Seq.

## Seq Query Examples

In Seq, you can filter events:

```
Application = "IdentityServer" and Name = "User Login Failure"
Application = "IdentityServer" and EventType = "Error"
```
