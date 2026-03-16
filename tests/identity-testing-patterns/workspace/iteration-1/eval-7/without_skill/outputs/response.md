# Testing a Custom IProfileService

## Unit Tests

```csharp
using Moq;
using System.Security.Claims;
using Xunit;

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
        _mockRepo.Setup(r => r.GetRolesAsync("user-1", It.IsAny<CancellationToken>()))
            .ReturnsAsync(new[] { "admin", "editor" });

        var subject = new ClaimsPrincipal(new ClaimsIdentity(
            new[] { new Claim("sub", "user-1") }));

        // Create a context - note the ProfileDataRequestContext constructor
        // requires subject, client, caller, and requested claim types
        var context = new Duende.IdentityServer.Models.ProfileDataRequestContext(
            subject, 
            new Duende.IdentityServer.Models.Client { ClientId = "test" }, 
            "test",
            new[] { "role" });

        await _service.GetProfileDataAsync(context);

        Assert.Contains(context.IssuedClaims, c => c.Type == "role" && c.Value == "admin");
        Assert.Contains(context.IssuedClaims, c => c.Type == "role" && c.Value == "editor");
    }

    [Fact]
    public async Task IsActive_ActiveUser_ReturnsTrue()
    {
        _mockRepo.Setup(r => r.IsActiveAsync("user-1", It.IsAny<CancellationToken>()))
            .ReturnsAsync(true);

        var subject = new ClaimsPrincipal(new ClaimsIdentity(
            new[] { new Claim("sub", "user-1") }));

        var context = new Duende.IdentityServer.Models.IsActiveContext(
            subject, 
            new Duende.IdentityServer.Models.Client { ClientId = "test" },
            "test");

        await _service.IsActiveAsync(context);

        Assert.True(context.IsActive);
    }

    [Fact]
    public async Task IsActive_InactiveUser_ReturnsFalse()
    {
        _mockRepo.Setup(r => r.IsActiveAsync("user-2", It.IsAny<CancellationToken>()))
            .ReturnsAsync(false);

        var subject = new ClaimsPrincipal(new ClaimsIdentity(
            new[] { new Claim("sub", "user-2") }));

        var context = new Duende.IdentityServer.Models.IsActiveContext(
            subject, 
            new Duende.IdentityServer.Models.Client { ClientId = "test" },
            "test");

        await _service.IsActiveAsync(context);

        Assert.False(context.IsActive);
    }
}
```

This tests the profile service in isolation by mocking the user repository and checking the context properties after calling the service methods.
