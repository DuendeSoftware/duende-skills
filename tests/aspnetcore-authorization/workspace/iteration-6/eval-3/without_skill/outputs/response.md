## ScopeRequirement and ScopeHandler

```csharp
using Microsoft.AspNetCore.Authorization;

public class ScopeRequirement : IAuthorizationRequirement
{
    public string Scope { get; }
    public ScopeRequirement(string scope) => Scope = scope;
}

public class ScopeHandler : AuthorizationHandler<ScopeRequirement>
{
    protected override Task HandleRequirementAsync(
        AuthorizationHandlerContext context, ScopeRequirement requirement)
    {
        var scopes = context.User.FindAll("scope")
            .SelectMany(c => c.Value.Split(' ', StringSplitOptions.RemoveEmptyEntries));

        if (scopes.Contains(requirement.Scope, StringComparer.Ordinal))
        {
            context.Succeed(requirement);
        }

        return Task.CompletedTask;
    }
}
```

`FindAll` handles both cases: a single space-delimited claim, or several separate `scope` claims. Each value is split on spaces.

## Registration in Program.cs

```csharp
builder.Services.AddSingleton<IAuthorizationHandler, ScopeHandler>();

builder.Services.AddAuthorization(options =>
{
    options.AddPolicy("catalog.read", policy =>
        policy.RequireAuthenticatedUser()
              .AddRequirements(new ScopeRequirement("catalog.read")));
});

var app = builder.Build();
app.UseAuthentication();
app.UseAuthorization();

app.MapGet("/products", () => Results.Ok(/* ... */)).RequireAuthorization("catalog.read");
```

The handler does not call `context.Fail()`. It simply doesn't succeed when the scope is missing, so other handlers for the same requirement can still grant access, and the requirement fails by default.
