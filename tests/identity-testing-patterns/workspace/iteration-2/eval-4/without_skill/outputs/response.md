# Unit Testing an Authorization Handler

You can test an `IAuthorizationHandler` directly without a web host by constructing the authorization context manually.

## Handler Under Test

```csharp
using Microsoft.AspNetCore.Authorization;
using System.Security.Claims;

public class MinimumAgeRequirement : IAuthorizationRequirement
{
    public int MinimumAge { get; }
    public MinimumAgeRequirement(int age) => MinimumAge = age;
}

public class MinimumAgeHandler : AuthorizationHandler<MinimumAgeRequirement>
{
    protected override Task HandleRequirementAsync(
        AuthorizationHandlerContext context,
        MinimumAgeRequirement requirement)
    {
        var birthdate = context.User.FindFirst("birthdate")?.Value;
        if (birthdate is null) return Task.CompletedTask;

        var age = DateTime.UtcNow.Year - DateTime.Parse(birthdate).Year;
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
    public async Task UserMeetsAge_Succeeds()
    {
        var user = new ClaimsPrincipal(new ClaimsIdentity(new[]
        {
            new Claim("birthdate", "1990-06-15")
        }, "Test"));

        var requirement = new MinimumAgeRequirement(18);
        var context = new AuthorizationHandlerContext(
            new[] { requirement }, user, null);

        await _handler.HandleAsync(context);

        Assert.True(context.HasSucceeded);
    }

    [Fact]
    public async Task UserTooYoung_DoesNotSucceed()
    {
        var user = new ClaimsPrincipal(new ClaimsIdentity(new[]
        {
            new Claim("birthdate",
                DateTime.UtcNow.AddYears(-10).ToString("yyyy-MM-dd"))
        }, "Test"));

        var requirement = new MinimumAgeRequirement(18);
        var context = new AuthorizationHandlerContext(
            new[] { requirement }, user, null);

        await _handler.HandleAsync(context);

        Assert.False(context.HasSucceeded);
    }
}
```

The key steps:
1. Create a `ClaimsPrincipal` with a `ClaimsIdentity` containing the `birthdate` claim
2. Construct an `AuthorizationHandlerContext` with the requirement, the user, and a null resource
3. Call `HandleAsync` on the handler
4. Check `context.HasSucceeded` for the expected result
