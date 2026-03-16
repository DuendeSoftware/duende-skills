# Scope-Based Authorization with Space-Delimited Scope Normalization

Here's how to implement scope-based authorization policies and handle space-delimited scope claims.

## Step 1: Define Authorization Policies

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

app.MapGet("/data", () => Results.Ok(new { message = "Protected data" }))
    .RequireAuthorization("read");

app.MapPost("/data", (DataModel model) => Results.Created($"/data/{model.Id}", model))
    .RequireAuthorization("write");

app.MapDelete("/data/{id}", (int id) => Results.NoContent())
    .RequireAuthorization("write");

app.Run();

public record DataModel(int Id, string Name, string Description);
```

## Step 2: Implement the IClaimsTransformation

IdentityServer can emit scopes in two formats depending on the `EmitScopesAsSpaceDelimitedStringInJwt` setting:

- **Array format (default):** `"scope": ["api1.read", "api1.write"]`
- **Space-delimited:** `"scope": "api1.read api1.write"`

When space-delimited, the `scope` claim is a single string. The `RequireClaim("scope", "api1.read")` policy check compares against the full string value, so it won't match. The solution is a custom `IClaimsTransformation` that splits it into individual claims:

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

This transformation:
1. Finds the `scope` claim on the principal
2. If it contains spaces (indicating space-delimited format), removes the original claim
3. Splits the string and adds each scope as an individual `scope` claim
4. Authorization policies then work correctly regardless of the format

## How the Policies Work

- `RequireClaim("scope", "api1.read")` checks that the user has a `scope` claim with value `api1.read`
- After the claims transformation, both array-format and space-delimited scopes produce individual claims
- The `"read"` policy is applied to `GET /data` via `.RequireAuthorization("read")`
- The `"write"` policy is applied to `POST /data` via `.RequireAuthorization("write")`
