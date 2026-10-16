# Unit testing MinimumAgeHandler directly

Handlers only need an `AuthorizationHandlerContext` – no host required. I'm assuming this shape (adjust to yours):

```csharp
public class MinimumAgeRequirement(int minimumAge) : IAuthorizationRequirement
{
    public int MinimumAge { get; } = minimumAge;
}

public class MinimumAgeHandler : AuthorizationHandler<MinimumAgeRequirement>
{
    protected override Task HandleRequirementAsync(AuthorizationHandlerContext context, MinimumAgeRequirement requirement)
    {
        var claim = context.User.FindFirst("birthdate");
        if (claim is null || !DateTime.TryParse(claim.Value, out var birth)) return Task.CompletedTask;

        var today = DateTime.Today;
        var age = today.Year - birth.Year;
        if (birth.Date > today.AddYears(-age)) age--;

        if (age >= requirement.MinimumAge) context.Succeed(requirement);
        return Task.CompletedTask;
    }
}
```

## Tests
```csharp
using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;

public class MinimumAgeHandlerTests
{
    private static AuthorizationHandlerContext CreateContext(MinimumAgeRequirement req, params Claim[] claims)
    {
        var user = new ClaimsPrincipal(new ClaimsIdentity(claims, "TestAuth"));
        return new AuthorizationHandlerContext(new[] { req }, user, resource: null);
    }

    [Fact]
    public async Task Succeeds_when_user_is_old_enough()
    {
        var req = new MinimumAgeRequirement(18);
        var birth = DateTime.Today.AddYears(-30).ToString("yyyy-MM-dd");
        var ctx = CreateContext(req, new Claim("birthdate", birth));

        await new MinimumAgeHandler().HandleAsync(ctx);

        Assert.True(ctx.HasSucceeded);
    }

    [Fact]
    public async Task Does_not_succeed_when_user_is_too_young()
    {
        var req = new MinimumAgeRequirement(18);
        var birth = DateTime.Today.AddYears(-10).ToString("yyyy-MM-dd");
        var ctx = CreateContext(req, new Claim("birthdate", birth));

        await new MinimumAgeHandler().HandleAsync(ctx);

        Assert.False(ctx.HasSucceeded);
        Assert.False(ctx.HasFailed);   // handler simply didn't succeed
    }

    [Fact]
    public async Task Does_not_succeed_without_birthdate_claim()
    {
        var req = new MinimumAgeRequirement(18);
        var ctx = CreateContext(req);
        await new MinimumAgeHandler().HandleAsync(ctx);
        Assert.False(ctx.HasSucceeded);
    }

    [Fact]
    public async Task Exactly_on_birthday_succeeds()
    {
        var req = new MinimumAgeRequirement(18);
        var ctx = CreateContext(req, new Claim("birthdate", DateTime.Today.AddYears(-18).ToString("yyyy-MM-dd")));
        await new MinimumAgeHandler().HandleAsync(ctx);
        Assert.True(ctx.HasSucceeded);
    }
}
```

`HandleAsync` is the public method on `IAuthorizationHandler`; the protected `HandleRequirementAsync` isn't directly callable. Note: using `DateTime.Today` makes tests time-dependent; inject `TimeProvider` (with `FakeTimeProvider` from `Microsoft.Extensions.TimeProvider.Testing`) for determinism.
