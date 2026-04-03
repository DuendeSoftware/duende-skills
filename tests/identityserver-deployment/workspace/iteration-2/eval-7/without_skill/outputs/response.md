# IdentityServer Events with Seq

## Enable Events

You'll need to enable event raising in IdentityServer options. Then create a custom sink to forward events to Seq.

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

var app = builder.Build();
app.UseIdentityServer();
app.Run();
```

For sending events to Seq, you would typically configure Serilog with the Seq sink and then use the logging pipeline. IdentityServer events will flow through the standard logging infrastructure.

You can configure Serilog like this:

```csharp
Log.Logger = new LoggerConfiguration()
    .WriteTo.Seq("http://localhost:5341")
    .CreateLogger();

builder.Host.UseSerilog();
```

This sends all structured logs (including IdentityServer events) to your Seq server.
