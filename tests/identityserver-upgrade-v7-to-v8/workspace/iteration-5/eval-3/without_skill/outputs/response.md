# Updating `IClock`-based time handling for v8

I'm working from general .NET knowledge here rather than a memorized v8 changelog, so confirm against Duende's official 8.0 upgrade notes. The good news is this is a well-established .NET modernization pattern.

## Background

Since .NET 8, the framework ships **`System.TimeProvider`**, an abstraction for getting the current time that's designed to be injected and faked in tests. Many libraries that previously shipped their own `IClock`-style abstraction have migrated to `TimeProvider`, and IdentityServer v8 follows that trend. So your custom `IClock` implementation should be replaced by consuming `TimeProvider`.

## Before

```csharp
public class CustomClock : IClock
{
    public DateTimeOffset UtcNow => DateTimeOffset.UtcNow;
}
```

## After — use `TimeProvider`

```csharp
public class CustomTokenValidator
{
    private readonly TimeProvider _timeProvider;

    public CustomTokenValidator(TimeProvider timeProvider)
        => _timeProvider = timeProvider;

    public bool IsExpired(DateTimeOffset expiresAt)
    {
        var now = _timeProvider.GetUtcNow();   // method, returns DateTimeOffset
        return now >= expiresAt;
    }
}
```

## Notes

- **`GetUtcNow()` is a method** on `TimeProvider`, replacing a `UtcNow` property. Use `.UtcDateTime` on the result if you need a plain `DateTime`.
- Inject `TimeProvider` via the constructor using standard DI. On modern .NET it's typically available from the container automatically; if not, register `TimeProvider.System` as a singleton.
- Remove your old `AddSingleton<IClock, CustomClock>()` registration and the `CustomClock` class.
- For unit tests, use `Microsoft.Extensions.Time.Testing.FakeTimeProvider` to control the clock.

Please verify the exact abstraction name and registration against the Duende 8.0 documentation, since I can't guarantee the specifics from memory.
