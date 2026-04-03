# Custom Scope Handler for Space-Delimited JWT Scopes

When scopes come as a space-delimited string in the JWT, the built-in `RequireClaim` won't match individual scopes. You need a custom requirement and handler.

## ScopeRequirement

```csharp
using Microsoft.AspNetCore.Authorization;

public class ScopeRequirement : IAuthorizationRequirement
{
    public string Scope { get; }
    public ScopeRequirement(string scope) => Scope = scope;
}
```

## ScopeHandler

```csharp
using Microsoft.AspNetCore.Authorization;

public class ScopeHandler : AuthorizationHandler<ScopeRequirement>
{
    protected override Task HandleRequirementAsync(
        AuthorizationHandlerContext context,
        ScopeRequirement requirement)
    {
        var scopeClaim = context.User.FindFirst("scope");
        if (scopeClaim is null)
        {
            context.Fail();
            return Task.CompletedTask;
        }

        var scopes = scopeClaim.Value.Split(' ');
        if (scopes.Contains(requirement.Scope))
        {
            context.Succeed(requirement);
        }
        else
        {
            context.Fail();
        }

        return Task.CompletedTask;
    }
}
```

## Registration in `Program.cs`

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

app.MapGet("/products", () => Results.Ok(new[]
{
    new { Id = 1, Name = "Widget", Price = 9.99 },
    new { Id = 2, Name = "Gadget", Price = 19.99 }
})).RequireAuthorization("catalog.read");

app.Run();
```

## Notes

- The `ScopeRequirement` holds the expected scope value.
- The `ScopeHandler` splits the scope string and checks if the required scope is present.
- If the scope is missing or doesn't match, `context.Fail()` is called to deny access.
