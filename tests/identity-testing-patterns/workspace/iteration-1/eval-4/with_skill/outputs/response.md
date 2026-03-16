# Unit Testing MinimumAgeHandler (IAuthorizationHandler)

## MinimumAgeRequirement and Handler (for reference)

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
        AuthorizationHandlerContext context, MinimumAgeRequirement requirement)
    {
        var birthDateClaim = context.User.FindFirst("birthdate");
        if (birthDateClaim is null) return Task.CompletedTask;

        var birthDate = DateOnly.Parse(birthDateClaim.Value);
        var age = DateOnly.FromDateTime(DateTime.UtcNow).Year - birthDate.Year;
        if (birthDate > DateOnly.FromDateTime(DateTime.UtcNow).AddYears(-age)) age--;

        if (age >= requirement.MinimumAge)
            context.Succeed(requirement);

        return Task.CompletedTask;
    }
}
```

## Unit Tests

```csharp
using Microsoft.AspNetCore.Authorization;
using System.Security.Claims;
using Xunit;

public class MinimumAgeHandlerTests
{
    private readonly MinimumAgeHandler _sut = new();

    [Fact]
    public async Task HandleRequirement_WithSufficientAge_ShouldSucceed()
    {
        // Arrange: user born in 1990 — well over 18
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
        // Arrange: user born 10 years ago — under 18
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
    public async Task HandleRequirement_WithNoBirthDateClaim_ShouldNotSucceed()
    {
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

**Key points:**
- A `ClaimsPrincipal` is created with a `ClaimsIdentity` containing a `birthdate` claim.
- An `AuthorizationHandlerContext` is constructed with the requirement, user principal, and resource (null in this case).
- `HandleAsync` is called directly on the handler — no web host is needed.
- `context.HasSucceeded` is checked to verify the authorization decision.
