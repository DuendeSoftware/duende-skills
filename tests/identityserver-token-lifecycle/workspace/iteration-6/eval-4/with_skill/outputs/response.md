```csharp
using System.Security.Claims;
using Duende.IdentityModel;
using Duende.IdentityServer.Extensions;
using Duende.IdentityServer.Models;
using Duende.IdentityServer.Services;

public class DatabaseProfileService : IProfileService
{
    private readonly IUserClaimsRepository _repo;   // hypothetical DB access

    public DatabaseProfileService(IUserClaimsRepository repo) => _repo = repo;

    public async Task GetProfileDataAsync(ProfileDataRequestContext context)
    {
        var sub = context.Subject.GetSubjectId();
        var claims = await _repo.GetClaimsAsync(sub);

        // Emits only claims whose types are in context.RequestedClaimTypes
        // (driven by the scopes/resources the client requested; respects consent)
        context.AddRequestedClaims(claims);

        // Token exchange: pass through the act claim
        if (context.Subject.GetAuthenticationMethod() == OidcConstants.GrantTypes.TokenExchange)
        {
            var act = context.Subject.FindFirst(JwtClaimTypes.Actor);
            if (act != null) context.IssuedClaims.Add(act);
        }
    }

    public async Task IsActiveAsync(IsActiveContext context)
    {
        context.IsActive = await _repo.IsActiveAsync(context.Subject.GetSubjectId());
    }
}

public interface IUserClaimsRepository
{
    Task<IEnumerable<Claim>> GetClaimsAsync(string subjectId);
    Task<bool> IsActiveAsync(string subjectId);
}
```

Registration:

```csharp
builder.Services.AddScoped<IUserClaimsRepository, UserClaimsRepository>();

builder.Services.AddIdentityServer()
    // ... existing config ...
    .AddProfileService<DatabaseProfileService>();
```

Why:
- `AddRequestedClaims` filters by scope, avoiding bloated tokens; `IssuedClaims.AddRange` would emit everything regardless. Use the userinfo endpoint for extra claims.
- `act` isn't a scope-requested claim, so it's added explicitly, and only when the authentication method is the token-exchange grant.
- Note `context.Caller` tells you whether you're serving an access token, identity token or userinfo; for userinfo, `Subject` holds claims from the access token, not the session.
- Alternatively, extend `DefaultProfileService` and override `GetProfileDataAsync`, as in the recommended pattern.
