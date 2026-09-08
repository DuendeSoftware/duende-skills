# Audit Trail: IdentityServer Events → Seq

IdentityServer's **events** are the right primitive for an audit trail — they emit structured, high-level records (login success/failure, token issuance, consent, errors) with usernames, subject/client ids, scopes, redirect URIs, and IPs (token values are obfuscated). Here's the full setup, plus the gotchas that bite people.

## 1. Enable events — they are OFF by default

**Events are NOT enabled by default.** You must turn them on in `AddIdentityServer`, or nothing is emitted at all:

```csharp
builder.Services.AddIdentityServer(options =>
{
    options.Events.RaiseSuccessEvents     = true;
    options.Events.RaiseFailureEvents     = true;
    options.Events.RaiseErrorEvents       = true;
    options.Events.RaiseInformationEvents = true;
})
// ...
```

## 2. Custom `IEventSink` for Seq — and it REPLACES the default sink

Implement `IEventSink` and register it. **Critical gotcha:** `IEventService` sends each event to **exactly ONE `IEventSink`**, so registering a custom sink **REPLACES the default (ASP.NET Core logger) sink**. If you still want your events in the normal log output, the custom sink must forward to `ILogger` itself:

```csharp
using Duende.IdentityServer.Events;
using Duende.IdentityServer.Services;

public sealed class SeqEventSink : IEventSink
{
    // The default logger sink is replaced — so log here to keep log output too.
    private readonly ILogger<SeqEventSink> _logger;
    public SeqEventSink(ILogger<SeqEventSink> logger) => _logger = logger;

    public Task PersistAsync(Event evt)
    {
        // Serilog's Seq sink picks this up via the logging pipeline; or POST to the
        // Seq ingestion API directly. Structured logging keeps all event properties.
        _logger.LogInformation("{Name} ({Category}/{Id}) {@Event}",
            evt.Name, evt.Category, evt.Id, evt);
        return Task.CompletedTask;
    }
}

// Registration — this REPLACES the built-in logger sink
builder.Services.AddTransient<IEventSink, SeqEventSink>();
```

Because you already use Serilog (`builder.Host.UseSerilog(...)`), add the Seq sink to Serilog (`Serilog.Sinks.Seq`) and the `LogInformation` above flows straight to Seq — while still keeping console logs. If you had bypassed logging and POSTed directly to Seq, you'd lose the normal log stream, which is exactly the trap the "one sink" rule creates.

## 3. UI login events must be raised by YOUR code

**IdentityServer only raises protocol events itself** (token issued, grants, consent, protocol errors). **UI actions — login success and failure — must be raised by your own UI code.** Inject `IEventService` into your login page/controller and call `RaiseAsync`:

```csharp
public class LoginModel : PageModel
{
    private readonly IEventService _events;
    public LoginModel(IEventService events) => _events = events;

    public async Task OnPost()
    {
        if (signInSucceeded)
        {
            await _events.RaiseAsync(
                new UserLoginSuccessEvent(user.Username, user.SubjectId, user.Username));
        }
        else
        {
            await _events.RaiseAsync(
                new UserLoginFailureEvent(username, "invalid credentials"));
        }
    }
}
```

Without these calls, your Seq audit trail will show token/protocol activity but **no interactive login successes or failures** — a common blind spot.

## Things you might miss (checklist)

- ✅ Events are **off by default** — forgetting to enable them yields an empty audit trail.
- ✅ A custom `IEventSink` **replaces** the default logger sink; forward to `ILogger` to keep log output.
- ✅ **UI login success/failure events are yours to raise** via `IEventService.RaiseAsync`; IdentityServer won't do it.
- ✅ Events can contain PII (usernames, IPs) — ensure Seq storage/retention meets your compliance requirements.
- ✅ `PersistAsync` runs in-request — keep it non-blocking; for high volume, buffer/queue rather than doing slow synchronous I/O to Seq.
