# Unit testing `MinimumAgeHandler` directly

Authorization handlers don't need a web host: construct an `AuthorizationHandlerContext` with a synthetic `ClaimsPrincipal` and call the public `HandleAsync` (from `IAuthorizationHandler`).

Assumed requirement/handler shape (adjust to yours):
```csharp
public sealed class MinimumAgeRequirement(int minimumAge) : IAuthorizationRequirement
{
    public int MinimumAge { get; } = minimumAge;
}
```

## Tests
```csharp
using System.Security.Claims;
using Duende.IdentityModel;
using Microsoft.AspNetCore.Authorization;

public class MinimumAgeHandlerTests
{
    private readonly MinimumAgeHandler _sut = new();

    private static AuthorizationHandlerContext CreateContext(MinimumAgeRequirement requirement, params Claim[] claims)
    {
        // authenticationType must be set, otherwise IsAuthenticated is false
        var user = new ClaimsPrincipal(new ClaimsIdentity(claims, "Bearer"));
        return new AuthorizationHandlerContext([requirement], user, resource: null);
    }

    [Fact]
    public async Task HandleRequirement_WithSufficientAge_ShouldSucceed()
    {
        var context = CreateContext(new MinimumAgeRequirement(18),
            new Claim(JwtClaimTypes.BirthDate, "1990-01-01"));

        await _sut.HandleAsync(context);

        Assert.True(context.HasSucceeded);
    }

    [Fact]
    public async Task HandleRequirement_WithInsufficientAge_ShouldNotSucceed()
    {
        var context = CreateContext(new MinimumAgeRequirement(18),
            new Claim(JwtClaimTypes.BirthDate, DateTime.UtcNow.AddYears(-10).ToString("yyyy-MM-dd")));

        await _sut.HandleAsync(context);

        Assert.False(context.HasSucceeded);
    }

    [Fact]
    public async Task HandleRequirement_WithoutBirthDateClaim_ShouldNotSucceed()
    {
        var context = CreateContext(new MinimumAgeRequirement(18));

        await _sut.HandleAsync(context);

        Assert.False(context.HasSucceeded);
    }
}
```

Notes:
- A handler that simply doesn't call `context.Succeed(...)` leaves `HasSucceeded == false` (the policy then fails with 403 in a real pipeline); it only sets `HasFailed` if it calls `context.Fail()`.
- Use a date relative to `DateTime.UtcNow` (or inject `TimeProvider`) so tests don't rot over time.
- This is the right level for handler logic. For verifying that a policy is actually enforced on an endpoint (401/403/200), use a `WebApplicationFactory` with a `TestAuthHandler` and a controllable `ClaimsPrincipal` instead.
- Packages: `xunit`, `Microsoft.NET.Test.Sdk`, and a framework reference to `Microsoft.AspNetCore.App` (for `Microsoft.AspNetCore.Authorization`).
