# Scope-Based Authorization for Your API

Here's how to implement scope-based authorization with policies for different endpoints.

## Define Authorization Policies

```csharp
// Program.cs
var builder = WebApplication.CreateBuilder(args);

builder.Services.AddControllers();

builder.Services.AddAuthentication("Bearer")
    .AddJwtBearer("Bearer", options =>
    {
        options.Authority = "https://identity.example.com";
        options.Audience = "api1";
    });

builder.Services.AddAuthorization(options =>
{
    options.AddPolicy("read", policy =>
    {
        policy.RequireAuthenticatedUser();
        policy.RequireClaim("scope", "api1.read");
    });

    options.AddPolicy("write", policy =>
    {
        policy.RequireAuthenticatedUser();
        policy.RequireClaim("scope", "api1.write");
    });
});

var app = builder.Build();

app.UseRouting();
app.UseAuthentication();
app.UseAuthorization();

app.MapControllers();

app.MapGet("/data", () => Results.Ok(new { message = "Protected data" }))
    .RequireAuthorization("read");

app.MapPost("/data", (DataModel model) => Results.Created($"/data/{model.Id}", model))
    .RequireAuthorization("write");

app.Run();

public record DataModel(int Id, string Name, string Description);
```

## Handling Space-Delimited Scopes

If your IdentityServer emits scopes as a space-delimited string (e.g., `"scope": "api1.read api1.write"`), the `RequireClaim` check may not work correctly since it expects individual claim values.

You can handle this by checking the claim value manually in a custom authorization requirement, or by parsing the scope string in your policy evaluation. One approach is to use a custom `IAuthorizationHandler`:

```csharp
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
        var scopeClaim = context.User.FindFirst("scope");
        if (scopeClaim != null)
        {
            var scopes = scopeClaim.Value.Split(' ');
            if (scopes.Contains(requirement.Scope))
            {
                context.Succeed(requirement);
            }
        }
        return Task.CompletedTask;
    }
}
```

Register the handler:

```csharp
builder.Services.AddSingleton<IAuthorizationHandler, ScopeHandler>();
```

This approach splits the space-delimited scope string and checks for the required scope value.
