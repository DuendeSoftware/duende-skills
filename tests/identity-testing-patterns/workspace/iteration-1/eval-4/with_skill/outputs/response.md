# Unit Testing MinimumAgeHandler

## Direct Unit Tests

Test `IAuthorizationHandler` implementations directly by constructing `AuthorizationHandlerContext` with synthetic claims. No web host needed.

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
        // Arrange: user born in 1990 (well over 18)
        var user = new ClaimsPrincipal(new ClaimsIdentity(new[]
        {
            new Claim(JwtClaimTypes.BirthDate, "1990-01-01")
        }, "Bearer"));

        var requirement = new MinimumAgeRequirement(18);
        var context = new AuthorizationHandlerContext(
            new[] { requirement }, user, resource: null);

        // Act
        await _sut.HandleAsync(context);

        // Assert
        Assert.True(context.HasSucceeded);
    }

    [Fact]
    public async Task HandleRequirement_WithInsufficientAge_ShouldNotSucceed()
    {
        // Arrange: user born 10 years ago (under 18)
        var user = new ClaimsPrincipal(new ClaimsIdentity(new[]
        {
            new Claim(JwtClaimTypes.BirthDate,
                DateTime.UtcNow.AddYears(-10).ToString("yyyy-MM-dd"))
        }, "Bearer"));

        var requirement = new MinimumAgeRequirement(18);
        var context = new AuthorizationHandlerContext(
            new[] { requirement }, user, resource: null);

        // Act
        await _sut.HandleAsync(context);

        // Assert
        Assert.False(context.HasSucceeded);
    }

    [Fact]
    public async Task HandleRequirement_WithExactAge_ShouldSucceed()
    {
        // Edge case: user is exactly 18 today
        var user = new ClaimsPrincipal(new ClaimsIdentity(new[]
        {
            new Claim(JwtClaimTypes.BirthDate,
                DateTime.UtcNow.AddYears(-18).ToString("yyyy-MM-dd"))
        }, "Bearer"));

        var requirement = new MinimumAgeRequirement(18);
        var context = new AuthorizationHandlerContext(
            new[] { requirement }, user, resource: null);

        await _sut.HandleAsync(context);

        Assert.True(context.HasSucceeded);
    }

    [Fact]
    public async Task HandleRequirement_WithMissingBirthdate_ShouldNotSucceed()
    {
        // No birthdate claim at all
        var user = new ClaimsPrincipal(new ClaimsIdentity(new[]
        {
            new Claim("sub", "user-001")
        }, "Bearer"));

        var requirement = new MinimumAgeRequirement(18);
        var context = new AuthorizationHandlerContext(
            new[] { requirement }, user, resource: null);

        await _sut.HandleAsync(context);

        Assert.False(context.HasSucceeded);
    }
}
```

## Key Points

- **No web host required**: `AuthorizationHandlerContext` is a plain class — construct it directly with the requirement, principal, and optional resource.
- **Real ClaimsPrincipal**: Build a `ClaimsPrincipal` with a `ClaimsIdentity` containing the claims the handler inspects.
- **Resource parameter**: Pass `null` for handlers that don't use resource-based authorization, or pass a specific resource object for handlers that do.
- **Check `context.HasSucceeded`**: The handler calls `context.Succeed(requirement)` internally. `HasSucceeded` is `true` only if all requirements have been satisfied.
