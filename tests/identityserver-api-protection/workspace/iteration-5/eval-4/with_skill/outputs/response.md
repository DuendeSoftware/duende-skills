# Scope-based authorization with space-delimited scope normalization

Two parts here:

1. Define **authorization policies** that require the `api1.read` / `api1.write` scopes and apply them per endpoint.
2. Add a **custom `IClaimsTransformation`** so it doesn't matter whether IdentityServer emits `scope` as a JSON array (default) or as a single space-delimited string.

## Why the transformation matters

IdentityServer's `EmitScopesAsSpaceDelimitedStringInJwt` setting controls the format:

| Setting           | `scope` claim                          |
| ----------------- | -------------------------------------- |
| `false` (default) | `["api1.read", "api1.write"]` (array)  |
| `true`            | `"api1.read api1.write"` (one string)  |

`RequireClaim("scope", "api1.read")` matches an individual claim value. If the scope arrives as one space-delimited string, the check fails silently. The transformation splits it into individual `scope` claims so policies work either way.

## ScopeClaimsTransformation.cs

```csharp
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
            foreach (var scope in scopeClaim.Value.Split(' ', StringSplitOptions.RemoveEmptyEntries))
            {
                identity.AddClaim(new Claim("scope", scope));
            }
        }

        return Task.FromResult(principal);
    }
}
```

## Program.cs

```csharp
var builder = WebApplication.CreateBuilder(args);

builder.Services.AddControllers();

builder.Services.AddAuthentication("Bearer")
    .AddJwtBearer("Bearer", options =>
    {
        options.Authority = "https://identity.example.com";
        options.Audience = "api1";
        options.TokenValidationParameters.ValidTypes = ["at+jwt"];
    });

// Register the claims transformation so space-delimited scopes are normalized
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

// GET requires api1.read, POST requires api1.write
app.MapGet("/data", () => Results.Ok(new { message = "Protected data" }))
    .RequireAuthorization("read");

app.MapPost("/data", (DataModel model) => Results.Created($"/data/{model.Id}", model))
    .RequireAuthorization("write");

app.Run();

public record DataModel(int Id, string Name, string Description);
```

Now the GET endpoint enforces `api1.read`, the POST enforces `api1.write`, and both work regardless of whether the scope claim arrives as an array or a space-delimited string.
