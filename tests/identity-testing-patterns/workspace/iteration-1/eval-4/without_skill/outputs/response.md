# Unit Testing MinimumAgeHandler

You can test authorization handlers directly without spinning up a web host.

```csharp
public class MinimumAgeHandlerTests
{
    [Fact]
    public async Task UserOldEnough_ShouldSucceed()
    {
        var handler = new MinimumAgeHandler();

        var claims = new ClaimsPrincipal(new ClaimsIdentity(new[]
        {
            new Claim("birthdate", "1990-06-15")
        }, "Test"));

        var requirement = new MinimumAgeRequirement(18);
        var context = new AuthorizationHandlerContext(
            new[] { requirement }, claims, null);

        await handler.HandleAsync(context);

        Assert.True(context.HasSucceeded);
    }

    [Fact]
    public async Task UserTooYoung_ShouldFail()
    {
        var handler = new MinimumAgeHandler();

        var claims = new ClaimsPrincipal(new ClaimsIdentity(new[]
        {
            new Claim("birthdate", DateTime.UtcNow.AddYears(-10).ToString("yyyy-MM-dd"))
        }, "Test"));

        var requirement = new MinimumAgeRequirement(18);
        var context = new AuthorizationHandlerContext(
            new[] { requirement }, claims, null);

        await handler.HandleAsync(context);

        Assert.False(context.HasSucceeded);
    }
}
```

This tests the handler in isolation — no HTTP server needed.
