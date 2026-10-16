# Unit testing a custom `IProfileService`

Test `GetProfileDataAsync` and `IsActiveAsync` directly with a mocked repository. Use **real** `ProfileDataRequestContext` / `IsActiveContext` instances (don't mock the context).

Assumed implementation:
```csharp
public interface IUserRepository
{
    Task<IReadOnlyList<string>> GetRolesAsync(string userId, CancellationToken ct);
    Task<bool> IsActiveAsync(string userId, CancellationToken ct);
}

public class CustomProfileService(IUserRepository users) : IProfileService
{
    public async Task GetProfileDataAsync(ProfileDataRequestContext context)
    {
        var sub = context.Subject.GetSubjectId();
        var roles = await users.GetRolesAsync(sub, CancellationToken.None);
        context.IssuedClaims.AddRange(roles.Select(r => new Claim(JwtClaimTypes.Role, r)));
    }

    public async Task IsActiveAsync(IsActiveContext context)
        => context.IsActive = await users.IsActiveAsync(context.Subject.GetSubjectId(), CancellationToken.None);
}
```

## Tests (xUnit + Moq)
```csharp
using System.Security.Claims;
using Duende.IdentityModel;
using Duende.IdentityServer.Models;
using Moq;

public class CustomProfileServiceTests
{
    private readonly CustomProfileService _sut;
    private readonly Mock<IUserRepository> _userRepo = new();

    public CustomProfileServiceTests() => _sut = new CustomProfileService(_userRepo.Object);

    private static ClaimsPrincipal Subject(string sub) =>
        new(new ClaimsIdentity([new Claim(JwtClaimTypes.Subject, sub)]));

    [Fact]
    public async Task GetProfileData_ShouldIncludeRoleClaimsForAccessToken()
    {
        _userRepo.Setup(r => r.GetRolesAsync("user-123", CancellationToken.None))
                 .ReturnsAsync(["admin", "billing"]);

        var context = new ProfileDataRequestContext(
            subject: Subject("user-123"),
            client: new Client { ClientId = "test.client" },
            caller: "test",
            requestedClaimTypes: [JwtClaimTypes.Role]);

        await _sut.GetProfileDataAsync(context);

        var roles = context.IssuedClaims.Where(c => c.Type == JwtClaimTypes.Role).Select(c => c.Value).ToList();
        Assert.Contains("admin", roles);
        Assert.Contains("billing", roles);
        _userRepo.Verify(r => r.GetRolesAsync("user-123", CancellationToken.None), Times.Once);
    }

    [Fact]
    public async Task GetProfileData_UserWithNoRoles_ShouldIssueNoRoleClaims()
    {
        _userRepo.Setup(r => r.GetRolesAsync("user-1", CancellationToken.None)).ReturnsAsync([]);

        var context = new ProfileDataRequestContext(Subject("user-1"),
            new Client { ClientId = "test.client" }, "test", [JwtClaimTypes.Role]);

        await _sut.GetProfileDataAsync(context);

        Assert.Empty(context.IssuedClaims);
    }

    [Fact]
    public async Task IsActive_WithDeactivatedUser_ShouldSetIsActiveFalse()
    {
        _userRepo.Setup(r => r.IsActiveAsync("user-deactivated", CancellationToken.None)).ReturnsAsync(false);

        var context = new IsActiveContext(Subject("user-deactivated"),
            new Client { ClientId = "test.client" }, "test");

        await _sut.IsActiveAsync(context);

        Assert.False(context.IsActive);
    }

    [Fact]
    public async Task IsActive_WithActiveUser_ShouldSetIsActiveTrue()
    {
        _userRepo.Setup(r => r.IsActiveAsync("user-ok", CancellationToken.None)).ReturnsAsync(true);

        var context = new IsActiveContext(Subject("user-ok"),
            new Client { ClientId = "test.client" }, "test");

        await _sut.IsActiveAsync(context);

        Assert.True(context.IsActive);
    }
}
```

## Caveat
In some Duende versions the `ProfileDataRequestContext` / `IsActiveContext` constructors may not be accessible. If that's the case, fall back to an integration test: host IdentityServer with `WebApplicationFactory`, register your profile service (with a fake `IUserRepository`) and the test clients, issue a real token, and inspect its claims with `JsonWebTokenHandler.ReadJsonWebToken`. That also verifies that the service is wired into the pipeline. Only mock external I/O (the repository), never the token pipeline.
