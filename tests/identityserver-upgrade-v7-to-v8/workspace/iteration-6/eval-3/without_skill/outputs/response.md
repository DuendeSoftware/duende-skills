# `IClock` in v8

I can't confirm it from memory, but I believe v8 drops Duende's own `IClock` in favour of .NET's built-in `TimeProvider`, which is the same direction ASP.NET Core took. Verify this against the upgrade notes.

**Before (v7)**
```csharp
public class CustomClock : IClock { public DateTimeOffset UtcNow => DateTimeOffset.UtcNow; }
builder.Services.AddSingleton<IClock, CustomClock>();
```

**After (v8, assuming `TimeProvider`)**
```csharp
builder.Services.AddSingleton<TimeProvider>(TimeProvider.System);
// or a custom subclass:
public class CustomClock : TimeProvider
{
    public override DateTimeOffset GetUtcNow() => DateTimeOffset.UtcNow;
}
```
In your validation code, inject `TimeProvider` and call `_time.GetUtcNow()` instead of `_clock.UtcNow`. For tests, use `FakeTimeProvider` from `Microsoft.Extensions.TimeProvider.Testing`.

If `IClock` still exists in v8, no change is needed. Compile and see.
