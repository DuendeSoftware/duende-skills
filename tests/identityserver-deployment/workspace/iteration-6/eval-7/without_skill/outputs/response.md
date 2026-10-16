# IdentityServer events → Seq

Enable events:

```csharp
builder.Services.AddIdentityServer(options =>
{
    options.Events.RaiseErrorEvents = true;
    options.Events.RaiseInformationEvents = true;
    options.Events.RaiseFailureEvents = true;
    options.Events.RaiseSuccessEvents = true;
})
.AddInMemoryIdentityResources(Config.IdentityResources)
.AddInMemoryApiScopes(Config.ApiScopes)
.AddInMemoryClients(Config.Clients)
.AddEventSink<SeqEventSink>();   // or register as IEventSink
```

Custom sink (Seq ingests via Serilog, so log structured):

```csharp
using Duende.IdentityServer.Events;
using Duende.IdentityServer.Services;

public class SeqEventSink : IEventSink
{
    private readonly ILogger<SeqEventSink> _logger;
    public SeqEventSink(ILogger<SeqEventSink> logger) => _logger = logger;

    public Task PersistAsync(Event evt)
    {
        _logger.LogInformation("IdentityServer event {@Event} {EventType} {Category} {Name} {Id}",
            evt, evt.EventType, evt.Category, evt.Name, evt.Id);
        return Task.CompletedTask;
    }
}
```

Serilog → Seq (`Serilog.AspNetCore`, `Serilog.Sinks.Seq`):

```csharp
builder.Host.UseSerilog((ctx, cfg) => cfg
    .MinimumLevel.Information()
    .Enrich.FromLogContext()
    .WriteTo.Seq("http://seq:5341", apiKey: ctx.Configuration["Seq:ApiKey"]));
```

Alternatively, write the sink directly to Seq with `Serilog.Log.Logger.ForContext("EventType", ...)`. Keep the sink fast and non-throwing; events can contain PII so secure Seq and consider what is logged.
