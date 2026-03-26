# Scope-Based Authorization with Space-Delimited Scope Handling

## Step 1: Define Authorization Policies

```csharp
var builder = WebApplication.CreateBuilder(args);

builder.Services.AddAuthentication("Bearer")
    .AddJwtBearer("Bearer", options =>
    {
        options.Authority = "https://identity.example.com";
        options.Audience = "api1";
        options.TokenValidationParameters.ValidTypes = ["at+jwt"];
    });

// Register claims transformation to handle space-delimited scopes
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

app.UseAuthentication();
app.UseAuthorization();

app.MapGet("/data", () => Results.Ok(new { message = "Protected data" }))
    .RequireAuthorization("read");

app.MapPost("/data", (DataModel model) => Results.Created($"/data/{model.Id}", model))
    .RequireAuthorization("write");

app.Run();
```

## Step 2: Handle Space-Delimited Scopes

IdentityServer can emit scopes as a space-delimited string (e.g., `"api1.read api1.write"`) depending on the `EmitScopesAsSpaceDelimitedStringInJwt` setting. When this happens, `RequireClaim("scope", "api1.read")` won't match because it looks for an exact claim value.

Implement `IClaimsTransformation` to split them:

```csharp
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

## Step 3: Register the Transformation

The `IClaimsTransformation` is registered in DI:

```csharp
builder.Services.AddTransient<IClaimsTransformation, ScopeClaimsTransformation>();
```

This ensures that regardless of the scope format, the authorization policies will correctly match individual scopes.
