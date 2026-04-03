# Unit Testing MinimumAgeHandler (IAuthorizationHandler)

Here's how to unit test an `IAuthorizationHandler` directly without spinning up a web host, using synthetic `ClaimsPrincipal` and `AuthorizationHandlerContext`.

## 1. The MinimumAgeRequirement and Handler (for reference)

```csharp
using Microsoft.AspNetCore.Authorization;
using System.Security.Claims;

public class MinimumAgeRequirement : IAuthorizationRequirement
{
    public int MinimumAge { get; }
    public MinimumAgeRequirement(int minimumAge) => MinimumAge = minimumAge;
}

public class MinimumAgeHandler : AuthorizationHandler<MinimumAgeRequirement>
{
    protected override Task HandleRequirementAsync(
        AuthorizationHandlerContext context,
        MinimumAgeRequirement requirement)
    {
        var birthdateClaim = context.User.FindFirst("birthdate");
        if (birthdateClaim is null)
            return Task.CompletedTask;

        var birthdate = DateOnly.Parse(birthdateClaim.Value);
        var age = DateOnly.FromDateTime(DateTime.UtcNow).Year - birthdate.Year;

        if (age >= requirement.MinimumAge)
            context.Succeed(requirement);

        return Task.CompletedTask;
    }
}
```

## 2. Unit Tests

```csharp
using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Xunit;

public class MinimumAgeHandlerTests
{
    private readonly MinimumAgeHandler _sut = new();

    [Fact]
    public async Task HandleRequirement_WithSufficientAge_ShouldSucceed()
    {
        // Arrange: a user born in 1990 — well over 18
        var user = new ClaimsPrincipal(new ClaimsIdentity(
        [
            new Claim("birthdate", "1990-01-01")
        ], "Bearer"));

        var requirement = new MinimumAgeRequirement(18);
        var context = new AuthorizationHandlerContext(
            [requirement], user, resource: null);

        // Act
        await _sut.HandleAsync(context);

        // Assert
        Assert.True(context.HasSucceeded);
    }

    [Fact]
    public async Task HandleRequirement_WithInsufficientAge_ShouldNotSucceed()
    {
        // Arrange: a user born 10 years ago — below the 18 requirement
        var user = new ClaimsPrincipal(new ClaimsIdentity(
        [
            new Claim("birthdate",
                DateTime.UtcNow.AddYears(-10).ToString("yyyy-MM-dd"))
        ], "Bearer"));

        var requirement = new MinimumAgeRequirement(18);
        var context = new AuthorizationHandlerContext(
            [requirement], user, resource: null);

        // Act
        await _sut.HandleAsync(context);

        // Assert
        Assert.False(context.HasSucceeded);
    }

    [Fact]
    public async Task HandleRequirement_WithNoBirthdateClaim_ShouldNotSucceed()
    {
        // Arrange: user has no birthdate claim at all
        var user = new ClaimsPrincipal(new ClaimsIdentity(
        [
            new Claim("sub", "user-123")
        ], "Bearer"));

        var requirement = new MinimumAgeRequirement(18);
        var context = new AuthorizationHandlerContext(
            [requirement], user, resource: null);

        await _sut.HandleAsync(context);

        Assert.False(context.HasSucceeded);
    }
}
```

Key points:
- A `ClaimsPrincipal` is created with a `ClaimsIdentity` containing a `birthdate` claim.
- An `AuthorizationHandlerContext` is constructed with the requirement, user principal, and a null resource.
- `HandleAsync` is called directly on the handler — no web host needed.
- `context.HasSucceeded` is `true` when the user meets the age requirement and `false` when they don't.
