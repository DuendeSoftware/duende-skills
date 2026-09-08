# Unit Testing a Custom IProfileService

A custom `IProfileService` can be tested in isolation by constructing the `ProfileDataRequestContext` and `IsActiveContext` that IdentityServer would normally pass in, providing a synthetic subject, and mocking the repository it depends on.

Suppose the service loads roles from a repository:

```csharp
public class CustomProfileService : IProfileService
{
    private readonly IUserRepository _users;
    public CustomProfileService(IUserRepository users) => _users = users;

    public async Task GetProfileDataAsync(ProfileDataRequestContext context)
    {
        var sub = context.Subject.FindFirst("sub")!.Value;
        var roles = await _users.GetRolesAsync(sub);
        foreach (var role in roles)
            context.IssuedClaims.Add(new Claim("role", role));
    }

    public async Task IsActiveAsync(IsActiveContext context)
    {
        var sub = context.Subject.FindFirst("sub")!.Value;
        context.IsActive = await _users.IsActiveAsync(sub);
    }
}
```

## Tests with a mocked repository

```csharp
using System.Security.Claims;
using Duende.IdentityServer.Models;
using Duende.IdentityServer.Services;
using Moq;
using Xunit;

public class CustomProfileServiceTests
{
    private readonly Mock<IUserRepository> _repo = new();
    private readonly CustomProfileService _sut;

    public CustomProfileServiceTests() => _sut = new CustomProfileService(_repo.Object);

    [Fact]
    public async Task GetProfileData_IssuesRoleClaims()
    {
        var subject = new ClaimsPrincipal(new ClaimsIdentity(new[]
        {
            new Claim("sub", "user-1")
        }));

        _repo.Setup(r => r.GetRolesAsync("user-1"))
             .ReturnsAsync(new[] { "admin", "manager" });

        var context = new ProfileDataRequestContext(
            subject,
            new Client { ClientId = "client1" },
            "test",
            new[] { "role" });

        await _sut.GetProfileDataAsync(context);

        var roles = context.IssuedClaims
            .Where(c => c.Type == "role")
            .Select(c => c.Value)
            .ToList();

        Assert.Contains("admin", roles);
        Assert.Contains("manager", roles);
    }

    [Fact]
    public async Task IsActive_UsesRepositoryResult()
    {
        var subject = new ClaimsPrincipal(new ClaimsIdentity(new[]
        {
            new Claim("sub", "user-1")
        }));

        _repo.Setup(r => r.IsActiveAsync("user-1")).ReturnsAsync(true);

        var context = new IsActiveContext(
            subject,
            new Client { ClientId = "client1" },
            "test");

        await _sut.IsActiveAsync(context);

        Assert.True(context.IsActive);
    }
}
```

## Notes
- The `ProfileDataRequestContext` is created with a subject principal containing a `sub` claim, plus a client, caller string, and requested claim types.
- Only `IUserRepository` is mocked — the profile service itself runs for real, and you assert on its outputs (`IssuedClaims`, `IsActive`).
- `GetProfileDataAsync` populates `context.IssuedClaims`; assert the expected `role` claims are present.
- `IsActiveAsync` sets `context.IsActive`; assert it matches what the mock returns.
- No IdentityServer host is started — this is a fast, isolated unit test.
