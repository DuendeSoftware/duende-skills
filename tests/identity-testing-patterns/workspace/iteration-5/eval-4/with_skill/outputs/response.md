# Unit Testing an IAuthorizationHandler Directly

You don't need a web host to test `MinimumAgeHandler`. An `IAuthorizationHandler` operates on an `AuthorizationHandlerContext`, which you can construct yourself with a synthetic `ClaimsPrincipal`. Call `HandleAsync` and inspect `context.HasSucceeded`.

Assuming a handler/requirement shaped like this:

```csharp
public sealed class MinimumAgeRequirement(int minimumAge) : IAuthorizationRequirement
{
    public int MinimumAge { get; } = minimumAge;
}

public sealed class MinimumAgeHandler : AuthorizationHandler<MinimumAgeRequirement>
{
    protected override Task HandleRequirementAsync(
        AuthorizationHandlerContext context, MinimumAgeRequirement requirement)
    {
        var birthDateClaim = context.User.FindFirst(c => c.Type == "birthdate");
        if (birthDateClaim is null)
            return Task.CompletedTask; // no claim => requirement not met

        var birthDate = DateTime.Parse(birthDateClaim.Value);
        var age = DateTime.Today.Year - birthDate.Year;
        if (birthDate > DateTime.Today.AddYears(-age)) age--;

        if (age >= requirement.MinimumAge)
            context.Succeed(requirement);

        return Task.CompletedTask;
    }
}
```

## The unit tests

```csharp
using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;

public class MinimumAgeHandlerTests
{
    private readonly MinimumAgeHandler _sut = new();

    [Fact]
    public async Task WithSufficientAge_ShouldSucceed()
    {
        // Arrange — a ClaimsPrincipal carrying a birthdate that clears 18
        var user = new ClaimsPrincipal(new ClaimsIdentity(
        [
            new Claim("birthdate", "1990-01-01")
        ], "TestAuth"));

        var requirement = new MinimumAgeRequirement(18);
        var context = new AuthorizationHandlerContext(
            [requirement], user, resource: null);

        // Act — invoke the handler directly
        await _sut.HandleAsync(context);

        // Assert
        Assert.True(context.HasSucceeded);
    }

    [Fact]
    public async Task WithInsufficientAge_ShouldNotSucceed()
    {
        // Arrange — a birthdate 10 years ago fails the age-18 requirement
        var user = new ClaimsPrincipal(new ClaimsIdentity(
        [
            new Claim("birthdate", DateTime.UtcNow.AddYears(-10).ToString("yyyy-MM-dd"))
        ], "TestAuth"));

        var requirement = new MinimumAgeRequirement(18);
        var context = new AuthorizationHandlerContext(
            [requirement], user, resource: null);

        // Act
        await _sut.HandleAsync(context);

        // Assert
        Assert.False(context.HasSucceeded);
    }
}
```

## Why this is enough
- `AuthorizationHandlerContext(requirements, user, resource)` is the exact contract the ASP.NET Core authorization middleware feeds the handler — constructing it yourself faithfully exercises the same code path.
- The synthetic `ClaimsPrincipal` lets you control the `birthdate` claim precisely for each scenario.
- `context.HasSucceeded` reflects whether `context.Succeed(requirement)` was called, giving you a clean pass/fail assertion — `true` for the qualifying user, `false` for the underage user.
- No `WebApplicationFactory`, no HTTP, no DI container needed.
