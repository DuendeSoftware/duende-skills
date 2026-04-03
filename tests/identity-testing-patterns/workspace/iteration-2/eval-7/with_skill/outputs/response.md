# Unit Testing a Custom IProfileService

Here's how to unit test a custom `IProfileService` implementation that loads roles from a database and adds them as claims, with a mocked user repository.

## 1. The IProfileService Implementation (for reference)

```csharp
using Duende.IdentityServer.Models;
using Duende.IdentityServer.Services;
using IdentityModel;
using System.Security.Claims;

public interface IUserRepository
{
    Task<IEnumerable<string>> GetRolesAsync(string subjectId, CancellationToken ct);
    Task<bool> IsActiveAsync(string subjectId, CancellationToken ct);
}

public class CustomProfileService : IProfileService
{
    private readonly IUserRepository _userRepo;

    public CustomProfileService(IUserRepository userRepo)
    {
        _userRepo = userRepo;
    }

    public async Task GetProfileDataAsync(ProfileDataRequestContext context)
    {
        var sub = context.Subject.FindFirstValue(JwtClaimTypes.Subject);
        var roles = await _userRepo.GetRolesAsync(sub!, CancellationToken.None);

        foreach (var role in roles)
        {
            context.IssuedClaims.Add(new Claim(JwtClaimTypes.Role, role));
        }
    }

    public async Task IsActiveAsync(IsActiveContext context)
    {
        var sub = context.Subject.FindFirstValue(JwtClaimTypes.Subject);
        context.IsActive = await _userRepo.IsActiveAsync(sub!, CancellationToken.None);
    }
}
```

## 2. Unit Tests

```csharp
using System.Security.Claims;
using Duende.IdentityServer.Models;
using Duende.IdentityServer.Services;
using IdentityModel;
using Moq;
using Xunit;

public class CustomProfileServiceTests
{
    private readonly CustomProfileService _sut;
    private readonly Mock<IUserRepository> _userRepo;

    public CustomProfileServiceTests()
    {
        _userRepo = new Mock<IUserRepository>();
        _sut = new CustomProfileService(_userRepo.Object);
    }

    [Fact]
    public async Task GetProfileData_ShouldIncludeRoleClaims()
    {
        // Arrange: a subject with known sub claim
        var subject = new ClaimsPrincipal(new ClaimsIdentity(
        [
            new Claim(JwtClaimTypes.Subject, "user-123")
        ]));

        _userRepo
            .Setup(r => r.GetRolesAsync("user-123", CancellationToken.None))
            .ReturnsAsync(["admin", "billing"]);

        var context = new ProfileDataRequestContext(
            subject: subject,
            client: new Client { ClientId = "test.client" },
            caller: "test",
            requestedClaimTypes: [JwtClaimTypes.Role]);

        // Act
        await _sut.GetProfileDataAsync(context);

        // Assert
        var roles = context.IssuedClaims
            .Where(c => c.Type == JwtClaimTypes.Role)
            .Select(c => c.Value)
            .ToList();

        Assert.Contains("admin", roles);
        Assert.Contains("billing", roles);
    }

    [Fact]
    public async Task IsActive_WithActiveUser_ShouldSetIsActiveTrue()
    {
        var subject = new ClaimsPrincipal(new ClaimsIdentity(
        [
            new Claim(JwtClaimTypes.Subject, "user-active")
        ]));

        _userRepo
            .Setup(r => r.IsActiveAsync("user-active", CancellationToken.None))
            .ReturnsAsync(true);

        var context = new IsActiveContext(
            subject: subject,
            client: new Client { ClientId = "test.client" },
            caller: "test");

        await _sut.IsActiveAsync(context);

        Assert.True(context.IsActive);
    }

    [Fact]
    public async Task IsActive_WithDeactivatedUser_ShouldSetIsActiveFalse()
    {
        var subject = new ClaimsPrincipal(new ClaimsIdentity(
        [
            new Claim(JwtClaimTypes.Subject, "user-deactivated")
        ]));

        _userRepo
            .Setup(r => r.IsActiveAsync("user-deactivated", CancellationToken.None))
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

Key points:
- `ProfileDataRequestContext` is constructed with a subject `ClaimsPrincipal` containing a `sub` claim.
- The `IUserRepository` is mocked (using Moq) to return known role values.
- `GetProfileDataAsync` is called and `context.IssuedClaims` is asserted to contain the expected role claims.
- `IsActiveAsync` is tested with both an active and deactivated user, asserting `context.IsActive` accordingly.
- No running IdentityServer is required — the service is tested in isolation.
