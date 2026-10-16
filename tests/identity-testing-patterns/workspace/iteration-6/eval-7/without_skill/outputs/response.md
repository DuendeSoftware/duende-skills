# Unit testing a custom IProfileService

Assumed implementation:

```csharp
public interface IUserRepository
{
    Task<AppUser?> FindByIdAsync(string id);
    Task<IReadOnlyList<string>> GetRolesAsync(string id);
}

public class DbProfileService(IUserRepository users) : IProfileService
{
    public async Task GetProfileDataAsync(ProfileDataRequestContext context)
    {
        var sub = context.Subject.GetSubjectId();
        var roles = await users.GetRolesAsync(sub);
        context.IssuedClaims.AddRange(roles.Select(r => new Claim(JwtClaimTypes.Role, r)));
    }

    public async Task IsActiveAsync(IsActiveContext context)
    {
        var user = await users.FindByIdAsync(context.Subject.GetSubjectId());
        context.IsActive = user is { IsActive: true };
    }
}
```

## Tests (xUnit + Moq)
```csharp
using System.Security.Claims;
using Duende.IdentityServer.Models;
using Duende.IdentityServer.Extensions;
using Moq;

public class DbProfileServiceTests
{
    private readonly Mock<IUserRepository> _repo = new();
    private DbProfileService CreateSut() => new(_repo.Object);

    private static ClaimsPrincipal Subject(string sub) =>
        new(new ClaimsIdentity(new[] { new Claim("sub", sub) }, "test"));

    [Fact]
    public async Task GetProfileData_adds_roles_as_claims()
    {
        _repo.Setup(r => r.GetRolesAsync("123")).ReturnsAsync(new[] { "admin", "editor" });

        var ctx = new ProfileDataRequestContext
        {
            Subject = Subject("123"),
            Client = new Client { ClientId = "test" },
            RequestedClaimTypes = new[] { "role" },
            Caller = "UserInfoEndpoint"
        };

        await CreateSut().GetProfileDataAsync(ctx);

        var roles = ctx.IssuedClaims.Where(c => c.Type == "role").Select(c => c.Value);
        Assert.Equal(new[] { "admin", "editor" }, roles);
        _repo.Verify(r => r.GetRolesAsync("123"), Times.Once);
    }

    [Fact]
    public async Task GetProfileData_with_no_roles_issues_nothing()
    {
        _repo.Setup(r => r.GetRolesAsync("123")).ReturnsAsync(Array.Empty<string>());
        var ctx = new ProfileDataRequestContext { Subject = Subject("123"), Client = new Client() };
        await CreateSut().GetProfileDataAsync(ctx);
        Assert.Empty(ctx.IssuedClaims);
    }

    [Fact]
    public async Task IsActive_true_for_active_user()
    {
        _repo.Setup(r => r.FindByIdAsync("123")).ReturnsAsync(new AppUser { Id = "123", IsActive = true });
        var ctx = new IsActiveContext(Subject("123"), new Client(), "test");
        await CreateSut().IsActiveAsync(ctx);
        Assert.True(ctx.IsActive);
    }

    [Fact]
    public async Task IsActive_false_for_disabled_user()
    {
        _repo.Setup(r => r.FindByIdAsync("123")).ReturnsAsync(new AppUser { Id = "123", IsActive = false });
        var ctx = new IsActiveContext(Subject("123"), new Client(), "test");
        await CreateSut().IsActiveAsync(ctx);
        Assert.False(ctx.IsActive);
    }

    [Fact]
    public async Task IsActive_false_for_unknown_user()
    {
        _repo.Setup(r => r.FindByIdAsync("999")).ReturnsAsync((AppUser?)null);
        var ctx = new IsActiveContext(Subject("999"), new Client(), "test");
        await CreateSut().IsActiveAsync(ctx);
        Assert.False(ctx.IsActive);
    }
}
```
Note: `ProfileDataRequestContext` has a parameterless constructor and settable properties, so you can build it directly. If you use `RequestedClaimTypes` filtering (`context.AddRequestedClaims`), populate it in the test accordingly. NSubstitute works equally well.
