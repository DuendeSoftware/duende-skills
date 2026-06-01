# Updating IClock for IdentityServer v8

If `IClock` has been removed or changed in IdentityServer v8, here are likely migration paths:

## Option 1: Use ISystemClock (ASP.NET Core)

```csharp
using Microsoft.AspNetCore.Authentication;

public class MyTokenValidator
{
    private readonly ISystemClock _clock;

    public MyTokenValidator(ISystemClock clock)
    {
        _clock = clock;
    }

    public bool IsTokenExpired(DateTimeOffset expiration)
    {
        return _clock.UtcNow > expiration;
    }
}
```

## Option 2: Use TimeProvider (.NET 8+)

If IdentityServer v8 has moved to the newer `TimeProvider` abstraction:

```csharp
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

## Registration

```csharp
// If using TimeProvider:
builder.Services.AddSingleton(TimeProvider.System);
```

Check the IdentityServer v8 release notes to confirm which abstraction they've adopted. The `TimeProvider` approach is the more modern pattern in .NET 8+.
