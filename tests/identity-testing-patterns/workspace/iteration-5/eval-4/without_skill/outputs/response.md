# Unit Testing MinimumAgeHandler Without a Web Host

An `AuthorizationHandler<T>` can be tested in isolation because everything it needs is passed via `AuthorizationHandlerContext`. You construct that context with a hand-built `ClaimsPrincipal`, invoke `HandleAsync`, and assert on `HasSucceeded`.

Given a typical handler:

```csharp
public class MinimumAgeRequirement : IAuthorizationRequirement
{
    public int MinimumAge { get; }
    public MinimumAgeRequirement(int minimumAge) => MinimumAge = minimumAge;
}

public class MinimumAgeHandler : AuthorizationHandler<MinimumAgeRequirement>
{
    protected override Task HandleRequirementAsync(
        AuthorizationHandlerContext context, MinimumAgeRequirement requirement)
    {
        var claim = context.User.FindFirst("birthdate");
        if (claim is null) return Task.CompletedTask;

        var dob = DateTime.Parse(claim.Value);
        var age = DateTime.Today.Year - dob.Year;
        if (dob.Date > DateTime.Today.AddYears(-age)) age--;

        if (age >= requirement.MinimumAge)
            context.Succeed(requirement);

        return Task.CompletedTask;
    }
}
```

## Tests

```csharp
using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Xunit;

public class MinimumAgeHandlerTests
{
    private readonly MinimumAgeHandler _handler = new();

    [Fact]
    public async Task MeetsAgeRequirement_Succeeds()
    {
        var user = new ClaimsPrincipal(new ClaimsIdentity(new[]
        {
            new Claim("birthdate", "1980-06-15")
        }, "Test"));

        var requirement = new MinimumAgeRequirement(18);
        var context = new AuthorizationHandlerContext(
            new[] { requirement }, user, resource: null);

        await _handler.HandleAsync(context);

        Assert.True(context.HasSucceeded);
    }

    [Fact]
    public async Task BelowAgeRequirement_Fails()
    {
        var tooYoung = DateTime.Today.AddYears(-15).ToString("yyyy-MM-dd");
        var user = new ClaimsPrincipal(new ClaimsIdentity(new[]
        {
            new Claim("birthdate", tooYoung)
        }, "Test"));

        var requirement = new MinimumAgeRequirement(18);
        var context = new AuthorizationHandlerContext(
            new[] { requirement }, user, resource: null);

        await _handler.HandleAsync(context);

        Assert.False(context.HasSucceeded);
    }
}
```

## Explanation
- `AuthorizationHandlerContext(requirements, user, resource)` is public, so you can new it up directly with a synthetic principal.
- Include a `ClaimsIdentity` with an authentication type so `User.Identity.IsAuthenticated` is true and the `birthdate` claim resolves.
- After `HandleAsync`, `context.HasSucceeded` is `true` only if the handler called `Succeed(requirement)` — `true` for the qualifying user, `false` for the underage one.
- This runs as a plain unit test — no `WebApplicationFactory`, HTTP, or DI required.
