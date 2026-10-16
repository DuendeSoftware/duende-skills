```csharp
using System.Security.Claims;
using Duende.IdentityServer.Models;
using Duende.IdentityServer.Services;

public class DatabaseProfileService : IProfileService
{
    private readonly IUserClaimsRepository _repo; // hypothetical DB access

    public DatabaseProfileService(IUserClaimsRepository repo) => _repo = repo;

    public async Task GetProfileDataAsync(ProfileDataRequestContext context)
    {
        var sub = context.Subject.GetSubjectId();

        // Load all claims from the database
        IEnumerable<Claim> dbClaims = await _repo.GetClaimsAsync(sub);

        // Only emit what the client's scopes requested
        context.AddRequestedClaims(dbClaims);   // filters by context.RequestedClaimTypes

        // Token exchange: pass through the actor claim
        var act = context.Subject.FindFirst("act");
        if (act != null && !context.IssuedClaims.Any(c => c.Type == "act"))
            context.IssuedClaims.Add(act);
    }

    public async Task IsActiveAsync(IsActiveContext context)
    {
        var sub = context.Subject.GetSubjectId();
        context.IsActive = await _repo.IsUserActiveAsync(sub);
    }
}

public interface IUserClaimsRepository
{
    Task<IEnumerable<Claim>> GetClaimsAsync(string subjectId);
    Task<bool> IsUserActiveAsync(string subjectId);
}
```

Registration:

```csharp
builder.Services.AddScoped<IUserClaimsRepository, UserClaimsRepository>();

builder.Services.AddIdentityServer()
    // ... existing config ...
    .AddProfileService<DatabaseProfileService>();
```

(`GetSubjectId()` is in `Duende.IdentityServer.Extensions`.)

Notes:
- `context.RequestedClaimTypes` is populated from the identity resources/API resources' user claims for the requested scopes. `AddRequestedClaims` filters on it, so unrequested claims are never emitted.
- The `act` claim isn't a "requested" user claim, hence it is added directly to `IssuedClaims`. In a token exchange, the extension grant validator supplies it in the subject's claims.
- Remove `.AddTestUsers(...)` in production when using your own user store; otherwise the test-user profile service may conflict/be replaced by yours (explicit `AddProfileService` takes precedence).
- `IsActiveAsync` is called on refresh/introspection, so keep it fast.
