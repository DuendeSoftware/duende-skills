# Unit Testing a Custom Authorization Handler

## MinimumAgeHandler Tests

```csharp
using Microsoft.AspNetCore.Authorization;
using System.Security.Claims;
using Xunit;

public class MinimumAgeHandlerTests
{
    private readonly MinimumAgeHandler _handler = new();

    [Fact]
    public async Task User_MeetsAgeRequirement_Succeeds()
    {
        var claims = new[]
        {
            new Claim("birthdate", "1990-05-15")
        };
        var user = new ClaimsPrincipal(new ClaimsIdentity(claims, "TestAuth"));

        var requirement = new MinimumAgeRequirement(18);
        var context = new AuthorizationHandlerContext(
            new[] { requirement }, user, null);

        await _handler.HandleAsync(context);

        Assert.True(context.HasSucceeded);
    }

    [Fact]
    public async Task User_DoesNotMeetAgeRequirement_Fails()
    {
        var claims = new[]
        {
            new Claim("birthdate", DateTime.UtcNow.AddYears(-10).ToString("yyyy-MM-dd"))
        };
        var user = new ClaimsPrincipal(new ClaimsIdentity(claims, "TestAuth"));

        var requirement = new MinimumAgeRequirement(18);
        var context = new AuthorizationHandlerContext(
            new[] { requirement }, user, null);

        await _handler.HandleAsync(context);

        Assert.False(context.HasSucceeded);
    }
}
```

This creates a `ClaimsPrincipal` with a birthdate claim, constructs an `AuthorizationHandlerContext`, and directly tests the handler without spinning up a web host.
