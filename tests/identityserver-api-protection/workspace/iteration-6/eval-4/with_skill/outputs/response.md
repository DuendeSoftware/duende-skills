# Scope-based authorization (including space-delimited scopes)

## Policies

```csharp
builder.Services.AddAuthentication("Bearer")
    .AddJwtBearer("Bearer", options =>
    {
        options.Authority = "https://identity.example.com";
        options.Audience = "api1";
        options.TokenValidationParameters.ValidTypes = ["at+jwt"];
    });

builder.Services.AddTransient<IClaimsTransformation, ScopeClaimsTransformation>();

builder.Services.AddAuthorization(options =>
{
    options.AddPolicy("read", p =>
    {
        p.RequireAuthenticatedUser();
        p.RequireClaim("scope", "api1.read");
    });
    options.AddPolicy("write", p =>
    {
        p.RequireAuthenticatedUser();
        p.RequireClaim("scope", "api1.write");
    });
});

var app = builder.Build();
app.UseRouting();
app.UseAuthentication();
app.UseAuthorization();

app.MapGet("/data", () => Results.Ok(new { message = "Data" })).RequireAuthorization("read");
app.MapPost("/data", (DataModel model) => Results.Created($"/data/{model.Id}", model)).RequireAuthorization("write");
app.MapDelete("/data/{id}", (int id) => Results.NoContent()).RequireAuthorization();

app.Run();

public record DataModel(int Id, string Name, string Description);
```

## Space-delimited scopes

IdentityServer emits scopes as a JSON array by default (one `scope` claim per value). With `EmitScopesAsSpaceDelimitedStringInJwt = true`, you get a single claim `"api1.read api1.write"`, and `RequireClaim("scope", "api1.read")` silently fails. Normalize with an `IClaimsTransformation`:

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
                identity.AddClaim(new Claim("scope", scope));
        }
        return Task.FromResult(principal);
    }
}
```

Now policies work regardless of the format. Don't forget this in production: it works in dev with arrays but breaks when the setting changes. (Note: a claims transformation can run more than once per request; the `Contains(' ')` check makes this one idempotent.)
