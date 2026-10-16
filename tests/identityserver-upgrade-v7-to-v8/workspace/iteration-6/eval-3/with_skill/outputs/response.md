# `IClock` → `TimeProvider` in v8

v8 removes IdentityServer's `IClock` in favour of .NET's `TimeProvider`. Note that `GetUtcNow()` (a method) replaces `UtcNow` (a property).

## Your registration
```csharp
// ❌ v7
builder.Services.AddSingleton<IClock, CustomClock>();

// ✅ v8 – the default
builder.Services.AddSingleton(TimeProvider.System);
```
If you really need custom time, for example for tests, subclass `TimeProvider`:
```csharp
public class CustomClock : TimeProvider
{
    public override DateTimeOffset GetUtcNow() => DateTimeOffset.UtcNow;
}
builder.Services.AddSingleton<TimeProvider, CustomClock>();
```
For tests, `FakeTimeProvider` from `Microsoft.Extensions.TimeProvider.Testing` is a good fit.

## Token validation code
```csharp
// ❌ v7
public class MyTokenValidation
{
    private readonly IClock _clock;
    public MyTokenValidation(IClock clock) => _clock = clock;
    public DateTime Now => _clock.UtcNow.UtcDateTime;
}

// ✅ v8
public class MyTokenValidation
{
    private readonly TimeProvider _timeProvider;
    public MyTokenValidation(TimeProvider timeProvider) => _timeProvider = timeProvider;
    public DateTime Now => _timeProvider.GetUtcNow().UtcDateTime;
}
```

## If you call the token validator
`ITokenValidator.ValidateAccessTokenAsync` has a new signature:
```csharp
await _validator.ValidateAccessTokenAsync(token, expectedScope: null, ct);
```

Also required for v8: `net10.0`, the 8.x packages, and `CancellationToken` on your custom async interfaces.
