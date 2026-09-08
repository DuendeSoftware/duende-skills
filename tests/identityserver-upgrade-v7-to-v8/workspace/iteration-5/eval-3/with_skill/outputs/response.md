# Replacing `IClock` with `TimeProvider` in v8

v8 removes Duende's `IClock` abstraction in favor of the built-in **`System.TimeProvider`** (introduced in .NET 8). Since IdentityServer targets .NET 10 in v8, `TimeProvider` is registered in DI for you, so you just inject it.

## Before (v7)

```csharp
public class CustomClock : IClock
{
    public DateTimeOffset UtcNow => DateTimeOffset.UtcNow;
}

// registration
builder.Services.AddSingleton<IClock, CustomClock>();
```

## After (v8) — inject `TimeProvider`

Delete the custom `IClock` class and its registration. In your custom token-validation code, inject `TimeProvider` through the constructor and call `GetUtcNow()`:

```csharp
public class CustomTokenValidator
{
    private readonly TimeProvider _timeProvider;

    public CustomTokenValidator(TimeProvider timeProvider)
        => _timeProvider = timeProvider;

    public bool IsExpired(DateTimeOffset expiresAt)
    {
        // v8: GetUtcNow() (method) replaces IClock.UtcNow (property)
        var now = _timeProvider.GetUtcNow();
        return now >= expiresAt;
    }
}
```

## Key points

- **`TimeProvider` replaces `IClock`.** Remove the `using Duende.IdentityServer` reference to `IClock` and delete `CustomClock` — you no longer implement a clock abstraction at all.
- **`GetUtcNow()` is a method**, not a property. Where you previously wrote `_clock.UtcNow`, write `_timeProvider.GetUtcNow()` (it returns `DateTimeOffset`; use `.UtcDateTime` if you need a `DateTime`).
- **Standard DI injection.** `TimeProvider` is available from the container by default — no `AddSingleton<IClock, ...>()` registration is needed. In tests you can substitute a `FakeTimeProvider` to control time.
- If you were also using `ICancellationTokenProvider`, note it is removed in v8 too — cancellation now flows through `CancellationToken` parameters on the interface methods.
