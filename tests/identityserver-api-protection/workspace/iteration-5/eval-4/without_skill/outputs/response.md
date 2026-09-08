# Per-endpoint scope authorization + handling space-delimited scopes

You need two things: authorization policies keyed on the `scope` claim, and a way to normalize the scope claim when it arrives as a single space-delimited string (OAuth tokens often carry `scope` as `"api1.read api1.write"`).

## 1. Normalize scopes with IClaimsTransformation

`IClaimsTransformation` runs after authentication and lets you reshape the principal. Here we split a space-delimited `scope` claim into separate `scope` claims so policy checks are uniform.

```csharp
using System.Security.Claims;
using Microsoft.AspNetCore.Authentication;

public class ScopeClaimsTransformation : IClaimsTransformation
{
    public Task<ClaimsPrincipal> TransformAsync(ClaimsPrincipal principal)
    {
        var identity = principal.Identity as ClaimsIdentity;
        if (identity is null) return Task.FromResult(principal);

        var scopeClaims = identity.FindAll("scope").ToList();
        foreach (var claim in scopeClaims)
        {
            if (claim.Value.Contains(' '))
            {
                identity.RemoveClaim(claim);
                foreach (var s in claim.Value.Split(' ', StringSplitOptions.RemoveEmptyEntries))
                {
                    identity.AddClaim(new Claim("scope", s));
                }
            }
        }

        return Task.FromResult(principal);
    }
}
```

## 2. Wire it up and define policies in Program.cs

```csharp
var builder = WebApplication.CreateBuilder(args);

builder.Services.AddControllers();

builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(options =>
    {
        options.Authority = "https://identity.example.com";
        options.Audience = "api1";
    });

// Register the transformation in DI
builder.Services.AddTransient<IClaimsTransformation, ScopeClaimsTransformation>();

builder.Services.AddAuthorization(options =>
{
    options.AddPolicy("ReadPolicy", p => p.RequireClaim("scope", "api1.read"));
    options.AddPolicy("WritePolicy", p => p.RequireClaim("scope", "api1.write"));
});

var app = builder.Build();

app.UseRouting();
app.UseAuthentication();
app.UseAuthorization();

app.MapControllers();

app.MapGet("/data", () => Results.Ok(new { message = "data" }))
    .RequireAuthorization("ReadPolicy");

app.MapPost("/data", (DataModel model) => Results.Created($"/data/{model.Id}", model))
    .RequireAuthorization("WritePolicy");

app.Run();

public record DataModel(int Id, string Name, string Description);
```

## Result

- `GET /data` → requires the `api1.read` scope.
- `POST /data` → requires the `api1.write` scope.
- Whether the identity provider emits `scope` as separate claims or one space-delimited string, the transformation normalizes it so `RequireClaim` always matches.

One caveat: the exact claim type may be `scope` or `http://schemas.microsoft.com/identity/claims/scope` depending on claim mapping; if policies don't match, inspect the actual claim type on the principal.
