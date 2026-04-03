# Scope-Based Authorization

## Setup

```csharp
var builder = WebApplication.CreateBuilder(args);

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

app.UseAuthentication();
app.UseAuthorization();

app.MapGet("/data", () => Results.Ok(new { message = "Data" }))
    .RequireAuthorization("read");

app.MapPost("/data", (DataModel model) => Results.Created($"/data/{model.Id}", model))
    .RequireAuthorization("write");

app.Run();

public record DataModel(int Id, string Name, string Description);
```

For handling space-delimited scopes, you might need a custom claims transformation that splits the scope string:

```csharp
public class ScopeTransformation : IClaimsTransformation
{
    public Task<ClaimsPrincipal> TransformAsync(ClaimsPrincipal principal)
    {
        var identity = (ClaimsIdentity)principal.Identity!;
        var scopeClaim = identity.FindFirst("scope");
        if (scopeClaim?.Value.Contains(' ') == true)
        {
            identity.RemoveClaim(scopeClaim);
            foreach (var s in scopeClaim.Value.Split(' '))
                identity.AddClaim(new Claim("scope", s));
        }
        return Task.FromResult(principal);
    }
}
```

Register it:
```csharp
builder.Services.AddTransient<IClaimsTransformation, ScopeTransformation>();
```
