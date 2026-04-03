# Scope-Based Authorization with Space-Delimited Scope Handling

## 1. Define Authorization Policies

```csharp
// Program.cs
var builder = WebApplication.CreateBuilder(args);

builder.Services.AddControllers();

builder.Services.AddAuthentication("Bearer")
    .AddJwtBearer("Bearer", options =>
    {
        options.Authority = "https://identity.example.com";
        options.Audience = "api1";
        options.TokenValidationParameters.ValidTypes = ["at+jwt"];
    });

// Register the claims transformation to normalize space-delimited scopes
builder.Services.AddTransient<IClaimsTransformation, ScopeClaimsTransformation>();

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

// Apply policies to endpoints
app.MapGet("/data", () => Results.Ok(new { message = "Protected data" }))
    .RequireAuthorization("read");

app.MapPost("/data", (DataModel model) => Results.Created($"/data/{model.Id}", model))
    .RequireAuthorization("write");

app.Run();

public record DataModel(int Id, string Name, string Description);
```

## 2. Implement Claims Transformation for Space-Delimited Scopes

IdentityServer can emit scopes either as a JSON array or a space-delimited string (controlled by `EmitScopesAsSpaceDelimitedStringInJwt`). When scopes are space-delimited, the `scope` claim appears as a single string like `"api1.read api1.write"`, which won't match `RequireClaim("scope", "api1.read")`. This transformation normalizes it:

```csharp
// ScopeClaimsTransformation.cs
using System.Security.Claims;
using Microsoft.AspNetCore.Authentication;

public class ScopeClaimsTransformation : IClaimsTransformation
{
    public Task<ClaimsPrincipal> TransformAsync(ClaimsPrincipal principal)
    {
        var identity = (ClaimsIdentity)principal.Identity!;
        var scopeClaim = identity.FindFirst("scope");
        if (scopeClaim != null && scopeClaim.Value.Contains(' '))
        {
            identity.RemoveClaim(scopeClaim);
            foreach (var scope in scopeClaim.Value.Split(' '))
            {
                identity.AddClaim(new Claim("scope", scope));
            }
        }
        return Task.FromResult(principal);
    }
}
```

This ensures authorization policies work correctly regardless of whether IdentityServer emits scopes as an array or space-delimited string.
