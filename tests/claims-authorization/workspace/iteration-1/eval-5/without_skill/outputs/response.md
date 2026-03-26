# Returning Different Claims for Identity vs Access Tokens

You can check what type of token is being issued in your `IProfileService` by looking at the context.

## Profile Service

```csharp
using System.Security.Claims;
using Duende.IdentityServer.Models;
using Duende.IdentityServer.Services;

public class TokenTypeAwareProfileService : IProfileService
{
    private readonly IUserRepository _users;

    public TokenTypeAwareProfileService(IUserRepository users)
    {
        _users = users;
    }

    public async Task GetProfileDataAsync(ProfileDataRequestContext context)
    {
        var subjectId = context.Subject.FindFirst("sub")?.Value;
        if (subjectId == null) return;

        var user = await _users.FindBySubjectIdAsync(subjectId);
        if (user == null) return;

        // Check if this is for an identity token or access token
        if (context.Caller == "ClaimsProviderIdentityToken")
        {
            // Keep identity tokens small
            context.IssuedClaims.Add(new Claim("name", user.DisplayName));
        }
        else
        {
            // Access tokens get richer claims
            context.IssuedClaims.Add(new Claim("name", user.DisplayName));
            context.IssuedClaims.Add(new Claim("email", user.Email));
            context.IssuedClaims.Add(new Claim("department", user.Department));
            context.IssuedClaims.Add(new Claim("role", user.Role));
        }
    }

    public Task IsActiveAsync(IsActiveContext context)
    {
        context.IsActive = true;
        return Task.CompletedTask;
    }
}
```

Register with:
```csharp
builder.Services.AddIdentityServer()
    .AddProfileService<TokenTypeAwareProfileService>();
```
