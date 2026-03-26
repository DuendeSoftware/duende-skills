# Testing IProfileService

You can unit test your profile service by mocking the user repository and constructing the appropriate context objects.

```csharp
public class ProfileServiceTests
{
    private readonly Mock<IUserRepository> _mockRepo;
    private readonly CustomProfileService _service;

    public ProfileServiceTests()
    {
        _mockRepo = new Mock<IUserRepository>();
        _service = new CustomProfileService(_mockRepo.Object);
    }

    [Fact]
    public async Task GetProfileData_AddsRoleClaims()
    {
        var subject = new ClaimsPrincipal(new ClaimsIdentity(new[]
        {
            new Claim("sub", "user-1")
        }));

        _mockRepo.Setup(r => r.GetRolesAsync("user-1", It.IsAny<CancellationToken>()))
            .ReturnsAsync(new[] { "admin", "editor" });

        // ProfileDataRequestContext constructor may vary by version
        var context = new ProfileDataRequestContext(
            subject, new Client { ClientId = "test" }, "ClaimsProviderAccessToken",
            new[] { "role" });

        await _service.GetProfileDataAsync(context);

        Assert.Contains(context.IssuedClaims, c => c.Type == "role" && c.Value == "admin");
        Assert.Contains(context.IssuedClaims, c => c.Type == "role" && c.Value == "editor");
    }

    [Fact]
    public async Task IsActive_ReturnsCorrectValue()
    {
        var subject = new ClaimsPrincipal(new ClaimsIdentity(new[]
        {
            new Claim("sub", "user-inactive")
        }));

        _mockRepo.Setup(r => r.IsActiveAsync("user-inactive", It.IsAny<CancellationToken>()))
            .ReturnsAsync(false);

        var context = new IsActiveContext(subject, new Client { ClientId = "test" }, "test");

        await _service.IsActiveAsync(context);

        Assert.False(context.IsActive);
    }
}
```

This tests the service in isolation without needing a running IdentityServer instance.
