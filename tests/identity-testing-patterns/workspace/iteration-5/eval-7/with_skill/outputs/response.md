# Unit Testing a Custom IProfileService

`IProfileService` has two methods — `GetProfileDataAsync` (which populates `IssuedClaims`) and `IsActiveAsync` (which sets `IsActive`). Both take a context object you can construct directly with a synthetic `ClaimsPrincipal`. Mock only the external dependency (the user repository); use the **real** context types so you test the actual contract.

Assume the service under test:

```csharp
public sealed class CustomProfileService(IUserRepository users) : IProfileService
{
    public async Task GetProfileDataAsync(ProfileDataRequestContext context)
    {
        var sub = context.Subject.FindFirst(JwtClaimTypes.Subject)!.Value;
        var roles = await users.GetRolesAsync(sub, CancellationToken.None);
        context.IssuedClaims.AddRange(roles.Select(r => new Claim(JwtClaimTypes.Role, r)));
    }

    public async Task IsActiveAsync(IsActiveContext context)
    {
        var sub = context.Subject.FindFirst(JwtClaimTypes.Subject)!.Value;
        context.IsActive = await users.IsActiveAsync(sub, CancellationToken.None);
    }
}
```

## The unit tests

```csharp
using System.Security.Claims;
using Duende.IdentityModel;                       // JwtClaimTypes
using Duende.IdentityServer.Models;               // Client
using Duende.IdentityServer.Services;             // ProfileDataRequestContext, IsActiveContext
using Moq;

public class CustomProfileServiceTests
{
    private readonly Mock<IUserRepository> _users = new();
    private readonly CustomProfileService _sut;

    public CustomProfileServiceTests() => _sut = new CustomProfileService(_users.Object);

    [Fact]
    public async Task GetProfileData_AddsRoleClaims()
    {
        // Arrange: subject principal carrying a sub claim
        var subject = new ClaimsPrincipal(new ClaimsIdentity(
        [
            new Claim(JwtClaimTypes.Subject, "user-123")
        ]));

        _users
            .Setup(r => r.GetRolesAsync("user-123", It.IsAny<CancellationToken>()))
            .ReturnsAsync(["admin", "billing"]);

        var context = new ProfileDataRequestContext(
            subject: subject,
            client: new Client { ClientId = "test.client" },
            caller: "UnitTest",
            requestedClaimTypes: [JwtClaimTypes.Role]);

        // Act
        await _sut.GetProfileDataAsync(context);

        // Assert: IssuedClaims contains the roles from the mocked repo
        var roles = context.IssuedClaims
            .Where(c => c.Type == JwtClaimTypes.Role)
            .Select(c => c.Value)
            .ToList();

        Assert.Contains("admin", roles);
        Assert.Contains("billing", roles);
    }

    [Fact]
    public async Task IsActive_ReflectsRepository()
    {
        var subject = new ClaimsPrincipal(new ClaimsIdentity(
        [
            new Claim(JwtClaimTypes.Subject, "user-deactivated")
        ]));

        _users
            .Setup(r => r.IsActiveAsync("user-deactivated", It.IsAny<CancellationToken>()))
            .ReturnsAsync(false);

        var context = new IsActiveContext(
            subject: subject,
            client: new Client { ClientId = "test.client" },
            caller: "UnitTest");

        await _sut.IsActiveAsync(context);

        Assert.False(context.IsActive);
    }

    [Fact]
    public async Task IsActive_ActiveUser_IsTrue()
    {
        var subject = new ClaimsPrincipal(new ClaimsIdentity(
        [
            new Claim(JwtClaimTypes.Subject, "user-active")
        ]));

        _users
            .Setup(r => r.IsActiveAsync("user-active", It.IsAny<CancellationToken>()))
            .ReturnsAsync(true);

        var context = new IsActiveContext(
            subject: subject,
            client: new Client { ClientId = "test.client" },
            caller: "UnitTest");

        await _sut.IsActiveAsync(context);

        Assert.True(context.IsActive);
    }
}
```

## Why this works in isolation
- `ProfileDataRequestContext(subject, client, caller, requestedClaimTypes)` and `IsActiveContext(subject, client, caller)` are the actual types IdentityServer passes into your service, so constructing them yourself exercises the real contract — no in-process host required.
- The `IUserRepository` is the only thing mocked; role/active data is deterministic and you assert on the *effects* the service produces (`IssuedClaims`, `IsActive`).
- Because nothing hits a token endpoint, these are fast, focused unit tests.

> **Version caveat:** in some Duende IdentityServer versions the `ProfileDataRequestContext` / `IsActiveContext` constructors are `internal`. If they aren't accessible from your test assembly, fall back to an in-process `WebApplicationFactory`: issue a real token for the user and assert the emitted claims with `JsonWebTokenHandler`.
