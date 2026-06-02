# Replacing IClock with TimeProvider in v8

In IdentityServer v8, `Duende.IdentityServer.IClock` is removed and replaced with the built-in `System.TimeProvider`.

## Migration

```csharp
// ❌ Before (v7)
public class CustomClock : IClock
{
    public DateTimeOffset UtcNow => DateTimeOffset.UtcNow;
}

// Registration:
builder.Services.AddSingleton<IClock, CustomClock>();
```

```csharp
// ✅ After (v8) — Use System.TimeProvider
public class MyTokenValidator
{
    private readonly TimeProvider _timeProvider;

    public MyTokenValidator(TimeProvider timeProvider)
    {
        _timeProvider = timeProvider;
    }

    public bool IsTokenExpired(DateTimeOffset expiration)
    {
        return _timeProvider.GetUtcNow() > expiration;
    }
}
```

## Key Changes

1. **Replace `Duende.IdentityServer.IClock`** with `System.TimeProvider`
2. **Use `GetUtcNow()` method** instead of `UtcNow` property
3. **Inject `TimeProvider`** via standard constructor DI
4. **Remove `ICancellationTokenProvider`** references — it's also removed in v8

## Registration

```csharp
// ❌ Remove
builder.Services.AddSingleton<IClock, CustomClock>();

// ✅ TimeProvider.System is registered by default in .NET
// For custom time (e.g., testing), register your own:
builder.Services.AddSingleton<TimeProvider>(new FakeTimeProvider());
```

`TimeProvider` is a standard .NET 8+ abstraction, so it also works well for unit testing with `Microsoft.Extensions.TimeProvider.Testing.FakeTimeProvider`.
