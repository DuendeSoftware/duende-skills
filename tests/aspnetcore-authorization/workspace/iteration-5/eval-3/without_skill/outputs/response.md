Some identity providers put all granted scopes into a single space-separated `scope` claim (e.g. `"catalog.read catalog.write"`). A plain `RequireClaim("scope", "catalog.read")` won't match that, so you need a custom requirement and handler that split the string and check for membership.

Here is a `ScopeRequirement` and `ScopeHandler`:

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
        AuthorizationHandlerContext context,
        ScopeRequirement requirement)
    {
        var scopeClaim = context.User.FindFirst("scope");
        if (scopeClaim is not null)
        {
            var scopes = scopeClaim.Value.Split(
                ' ', StringSplitOptions.RemoveEmptyEntries);

            if (scopes.Contains(requirement.Scope))
            {
                context.Succeed(requirement);
            }
        }

        return Task.CompletedTask;
    }
}
```

Register the handler and define the policy in `Program.cs`:

```csharp
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Authorization;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(options =>
    {
        options.Authority = builder.Configuration["Authentication:Authority"];
        options.Audience = builder.Configuration["Authentication:Audience"];
    });

builder.Services.AddSingleton<IAuthorizationHandler, ScopeHandler>();

builder.Services.AddAuthorization(options =>
{
    options.AddPolicy("catalog.read", policy =>
        policy.Requirements.Add(new ScopeRequirement("catalog.read")));
});

var app = builder.Build();

app.UseAuthentication();
app.UseAuthorization();

app.MapGet("/products", () => Results.Ok())
    .RequireAuthorization("catalog.read");

app.Run();
```

Key points:

- `ScopeRequirement` implements `IAuthorizationRequirement` and just carries the scope name.
- `ScopeHandler` derives from `AuthorizationHandler<ScopeRequirement>` and splits the claim on spaces with `Split(' ', ...)`.
- The handler calls `context.Succeed(requirement)` only when the scope is present; when it isn't, it just returns without failing so the request can still be evaluated by other handlers.
- You must register the handler with `AddSingleton<IAuthorizationHandler, ScopeHandler>()`, otherwise the requirement never runs and the policy always denies.
- `policy.Requirements.Add(new ScopeRequirement("catalog.read"))` attaches the requirement to the named policy.
