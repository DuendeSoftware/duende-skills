# Different Claims for Identity vs Access Tokens

You can check what type of token is being generated in your `IProfileService` implementation and return different claims accordingly.

## Implementation

```csharp
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

        // Check the caller to determine token type
        if (context.Caller == "ClaimsProviderIdentityToken")
        {
            // Keep identity tokens small
            context.IssuedClaims.Add(new Claim("name", user.DisplayName));
        }
        else
        {
            // Richer claims for access tokens
            context.IssuedClaims.AddRange(new[]
            {
                new Claim("name", user.DisplayName),
                new Claim("email", user.Email),
                new Claim("department", user.Department),
                new Claim("tenant_id", user.TenantId),
            });
        }
    }

    public Task IsActiveAsync(IsActiveContext context)
    {
        context.IsActive = true;
        return Task.CompletedTask;
    }
}
```

Register it:

```csharp
builder.Services.AddIdentityServer()
    .AddProfileService<TokenTypeAwareProfileService>();
```

The `context.Caller` property tells you what's requesting the claims, so you can customize the response for each token type.
