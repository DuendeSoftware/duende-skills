# Unit Testing a Custom IProfileService

## The Profile Service Under Test

```csharp
public sealed class CustomProfileService : IProfileService
{
    private readonly IUserRepository _userRepo;

    public CustomProfileService(IUserRepository userRepo) => _userRepo = userRepo;

    public async Task GetProfileDataAsync(ProfileDataRequestContext context)
    {
        var sub = context.Subject.FindFirst(JwtClaimTypes.Subject)?.Value;
        if (sub is null) return;

        var roles = await _userRepo.GetRolesAsync(sub, CancellationToken.None);
        foreach (var role in roles)
        {
            context.IssuedClaims.Add(new Claim(JwtClaimTypes.Role, role));
        }
    }

    public async Task IsActiveAsync(IsActiveContext context)
    {
        var sub = context.Subject.FindFirst(JwtClaimTypes.Subject)?.Value;
        if (sub is null)
        {
            context.IsActive = false;
            return;
        }

        context.IsActive = await _userRepo.IsActiveAsync(sub, CancellationToken.None);
    }
}
```

## Unit Tests

```csharp
using System.Security.Claims;
using Duende.IdentityServer.Models;
using Duende.IdentityServer.Validation;
using IdentityModel;
using Moq;
using Xunit;

public class CustomProfileServiceTests
{
    private readonly Mock<IUserRepository> _userRepo;
    private readonly CustomProfileService _sut;

    public CustomProfileServiceTests()
    {
        _userRepo = new Mock<IUserRepository>();
        _sut = new CustomProfileService(_userRepo.Object);
    }

    [Fact]
    public async Task GetProfileData_ShouldIncludeRoleClaims()
    {
        // Arrange: subject with known sub claim
        var subject = new ClaimsPrincipal(new ClaimsIdentity(new[]
        {
            new Claim(JwtClaimTypes.Subject, "user-123")
        }));

        _userRepo
            .Setup(r => r.GetRolesAsync("user-123", It.IsAny<CancellationToken>()))
            .ReturnsAsync(new[] { "admin", "billing" });

        var context = new ProfileDataRequestContext(
            subject: subject,
            client: new Client { ClientId = "test.client" },
            caller: "test",
            requestedClaimTypes: new[] { JwtClaimTypes.Role });

        // Act
        await _sut.GetProfileDataAsync(context);

        // Assert
        var roles = context.IssuedClaims
            .Where(c => c.Type == JwtClaimTypes.Role)
            .Select(c => c.Value)
            .ToList();

        Assert.Contains("admin", roles);
        Assert.Contains("billing", roles);
        Assert.Equal(2, roles.Count);
    }

    [Fact]
    public async Task IsActive_ActiveUser_ShouldSetIsActiveTrue()
    {
        var subject = new ClaimsPrincipal(new ClaimsIdentity(new[]
        {
            new Claim(JwtClaimTypes.Subject, "user-123")
        }));

        _userRepo
            .Setup(r => r.IsActiveAsync("user-123", It.IsAny<CancellationToken>()))
            .ReturnsAsync(true);

        var context = new IsActiveContext(
            subject: subject,
            client: new Client { ClientId = "test.client" },
            caller: "test");

        await _sut.IsActiveAsync(context);

        Assert.True(context.IsActive);
    }

    [Fact]
    public async Task IsActive_DeactivatedUser_ShouldSetIsActiveFalse()
    {
        var subject = new ClaimsPrincipal(new ClaimsIdentity(new[]
        {
            new Claim(JwtClaimTypes.Subject, "user-deactivated")
        }));

        _userRepo
            .Setup(r => r.IsActiveAsync("user-deactivated", It.IsAny<CancellationToken>()))
            .ReturnsAsync(false);

        var context = new IsActiveContext(
            subject: subject,
            client: new Client { ClientId = "test.client" },
            caller: "test");

        await _sut.IsActiveAsync(context);

        Assert.False(context.IsActive);
    }
}
```

## Key Points

- **No running IdentityServer needed**: These tests instantiate the profile service directly and call its methods with constructed contexts.
- **Mock only the external dependency** (`IUserRepository`), not the IdentityServer contexts.
- **`ProfileDataRequestContext`** takes `subject`, `client`, `caller`, and `requestedClaimTypes`. After calling `GetProfileDataAsync`, inspect `context.IssuedClaims`.
- **`IsActiveContext`** takes `subject`, `client`, and `caller`. After calling `IsActiveAsync`, inspect `context.IsActive`.
