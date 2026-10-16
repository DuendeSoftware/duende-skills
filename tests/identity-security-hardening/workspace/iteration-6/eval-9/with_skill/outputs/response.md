# Audit trail: IdentityServer events → Seq

## 1. Events are NOT enabled by default
```csharp
builder.Services.AddIdentityServer(options =>
{
    options.Events.RaiseSuccessEvents = true;
    options.Events.RaiseFailureEvents = true;
    options.Events.RaiseErrorEvents = true;
    options.Events.RaiseInformationEvents = true;
});
```

## 2. Serilog → Seq
```
dotnet add package Serilog.Sinks.Seq
```
```csharp
builder.Host.UseSerilog((ctx, lc) => lc
    .WriteTo.Console()
    .WriteTo.Seq(ctx.Configuration["Seq:Url"]!, apiKey: ctx.Configuration["Seq:ApiKey"])
    .ReadFrom.Configuration(ctx.Configuration));
```

## 3. Custom sink
```csharp
public sealed class SeqEventSink : IEventSink
{
    private readonly ILogger<SeqEventSink> _logger; // the default sink is replaced, so log here
    public SeqEventSink(ILogger<SeqEventSink> logger) => _logger = logger;

    public Task PersistAsync(Event evt)
    {
        _logger.LogInformation("{Name} ({Id}) {@Event}", evt.Name, evt.Id, evt);
        return Task.CompletedTask;
    }
}

// after AddIdentityServer():
builder.Services.AddTransient<IEventSink, SeqEventSink>();
```
Because the `ILogger` is backed by Serilog, events land in Seq as structured properties (`{@Event}`), searchable by `Name`, `ClientId`, `SubjectId`, etc.

## 4. UI logins (failed and successful)
IdentityServer raises **protocol** events itself, but **login success/failure happen in *your* UI code**, so you must raise them via `IEventService`:

```csharp
public LoginModel(IEventService events, ...) => _events = events;

// on success
await _events.RaiseAsync(new UserLoginSuccessEvent(user.Username, user.SubjectId, user.Username, clientId: context?.Client.ClientId));

// on failure
await _events.RaiseAsync(new UserLoginFailureEvent(Input.Username, "invalid credentials", clientId: context?.Client.ClientId));
```
Raise the failure event for every failure path (unknown user, bad password, locked out).

## Things you might miss
1. **A custom sink REPLACES the default sink.** `IEventService` sends each event to exactly one `IEventSink`; the default ASP.NET Core logger sink disappears, so forward to logging in your sink (as above) or you'll lose output.
2. **Failure/success flags** default to off; without them nothing is emitted. The checklist requires `RaiseErrorEvents` and `RaiseFailureEvents` both `true`.
3. **UI events aren't automatic** (see section 4).
4. **Sensitive data**: events can contain usernames, subject/client ids, scopes, redirect URIs and IPs (token values are obfuscated). Treat Seq as sensitive: TLS, API keys, access control, retention policy / GDPR.
5. **Real client IPs** behind a proxy require `UseForwardedHeaders` with a restricted `KnownProxies`.
6. **Custom events** must derive from `Event` and use a unique event id.
7. Keep the sink fast; Serilog's Seq sink batches asynchronously. Flush on shutdown (`Log.CloseAndFlush()`).
8. Alert in Seq on spikes of `UserLoginFailure` / `TokenIssuedFailure`.
