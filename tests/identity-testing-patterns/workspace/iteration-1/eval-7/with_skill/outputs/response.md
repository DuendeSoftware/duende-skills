# Unit Testing a Custom IProfileService

## Custom Profile Service (System Under Test)

```csharp
using Duende.IdentityServer.Models;
using Duende.IdentityServer.Services;
using System.Security.Claims;

public class CustomProfileService : IProfileService
{
    private readonly IUserRepository _userRepo;

    public CustomProfileService(IUserRepository userRepo) => _userRepo = userRepo;

    public async Task GetProfileDataAsync(ProfileDataRequestContext context)
    {
        var subClaim = context.Subject.FindFirst("sub");
        if (subClaim is null) return;

        var roles = await _userRepo.GetRolesAsync(subClaim.Value, CancellationToken.None);
        foreach (var role in roles)
        {
            context.IssuedClaims.Add(new Claim("role", role));
        }
    }

    public async Task IsActiveAsync(IsActiveContext context)
    {
        var subClaim = context.Subject.FindFirst("sub");
        if (subClaim is null)
        {
            context.IsActive = false;
            return;
        }

        context.IsActive = await _userRepo.IsActiveAsync(subClaim.Value, CancellationToken.None);
    }
}

public interface IUserRepository
{
    Task<IEnumerable<string>> GetRolesAsync(string subjectId, CancellationToken ct);
    Task<bool> IsActiveAsync(string subjectId, CancellationToken ct);
}
```

## Unit Tests

```csharp
using Duende.IdentityServer.Models;
using IdentityModel;
using Moq;
using System.Security.Claims;
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
        // Arrange
        var subject = new ClaimsPrincipal(new ClaimsIdentity(
        [
            new Claim(JwtClaimTypes.Subject, "user-123")
        ]));

        _userRepo
            .Setup(r => r.GetRolesAsync("user-123", CancellationToken.None))
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
            .Where(c => c.Type == "role")
            .Select(c => c.Value)
            .ToList();

        Assert.Contains("admin", roles);
        Assert.Contains("billing", roles);
    }

    [Fact]
    public async Task IsActive_WithActiveUser_ShouldReturnTrue()
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
    public async Task IsActive_WithDeactivatedUser_ShouldReturnFalse()
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

**Key points:**
- `ProfileDataRequestContext` is constructed with a subject `ClaimsPrincipal` containing a `sub` claim.
- `IUserRepository` is mocked to return known role values.
- `GetProfileDataAsync` is called and `context.IssuedClaims` is checked for the expected role claims.
- `IsActiveAsync` is tested with both active and inactive user mocks.
- No running IdentityServer is needed — the service is tested in isolation.
