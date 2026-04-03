# Testing a Custom IProfileService

You can unit test an `IProfileService` by constructing the required contexts and mocking the dependencies.

## Profile Service

```csharp
using Duende.IdentityServer.Models;
using Duende.IdentityServer.Services;
using System.Security.Claims;

public interface IUserRepository
{
    Task<IEnumerable<string>> GetRolesAsync(string userId, CancellationToken ct);
    Task<bool> IsActiveAsync(string userId, CancellationToken ct);
}

public class RoleProfileService : IProfileService
{
    private readonly IUserRepository _repo;
    public RoleProfileService(IUserRepository repo) => _repo = repo;

    public async Task GetProfileDataAsync(ProfileDataRequestContext context)
    {
        var sub = context.Subject.FindFirst("sub")?.Value;
        var roles = await _repo.GetRolesAsync(sub!, CancellationToken.None);
        foreach (var role in roles)
            context.IssuedClaims.Add(new Claim("role", role));
    }

    public async Task IsActiveAsync(IsActiveContext context)
    {
        var sub = context.Subject.FindFirst("sub")?.Value;
        context.IsActive = await _repo.IsActiveAsync(sub!, CancellationToken.None);
    }
}
```

## Tests

```csharp
using System.Security.Claims;
using Duende.IdentityServer.Models;
using Moq;
using Xunit;

public class RoleProfileServiceTests
{
    private readonly Mock<IUserRepository> _repo = new();
    private readonly RoleProfileService _service;

    public RoleProfileServiceTests()
    {
        _service = new RoleProfileService(_repo.Object);
    }

    [Fact]
    public async Task GetProfileData_AddsRoleClaims()
    {
        var subject = new ClaimsPrincipal(
            new ClaimsIdentity(new[] { new Claim("sub", "user-1") }));

        _repo.Setup(r => r.GetRolesAsync("user-1", CancellationToken.None))
            .ReturnsAsync(new[] { "admin", "editor" });

        var context = new ProfileDataRequestContext(
            subject: subject,
            client: new Client { ClientId = "test" },
            caller: "test",
            requestedClaimTypes: new[] { "role" });

        await _service.GetProfileDataAsync(context);

        var roles = context.IssuedClaims
            .Where(c => c.Type == "role")
            .Select(c => c.Value);
        Assert.Contains("admin", roles);
        Assert.Contains("editor", roles);
    }

    [Fact]
    public async Task IsActive_ReturnsFalseForInactiveUser()
    {
        var subject = new ClaimsPrincipal(
            new ClaimsIdentity(new[] { new Claim("sub", "inactive-user") }));

        _repo.Setup(r => r.IsActiveAsync("inactive-user", CancellationToken.None))
            .ReturnsAsync(false);

        var context = new IsActiveContext(
            subject: subject,
            client: new Client { ClientId = "test" },
            caller: "test");

        await _service.IsActiveAsync(context);

        Assert.False(context.IsActive);
    }
}
```

This tests the profile service in complete isolation — no IdentityServer needed. The repository is mocked with Moq, and the Duende contexts are constructed directly.
