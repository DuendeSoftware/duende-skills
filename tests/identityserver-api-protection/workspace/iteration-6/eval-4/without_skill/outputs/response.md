# Scope-based authorization

First add JWT bearer authentication (authority/audience as appropriate), then define policies.

```csharp
builder.Services.AddAuthentication("Bearer")
    .AddJwtBearer("Bearer", o =>
    {
        o.Authority = "https://identity.example.com";
        o.Audience = "api1";
        o.MapInboundClaims = false;
    });

builder.Services.AddSingleton<IAuthorizationHandler, ScopeHandler>();

builder.Services.AddAuthorization(options =>
{
    options.AddPolicy("ReadPolicy", p => p.RequireAuthenticatedUser()
        .AddRequirements(new ScopeRequirement("api1.read")));
    options.AddPolicy("WritePolicy", p => p.RequireAuthenticatedUser()
        .AddRequirements(new ScopeRequirement("api1.write")));
});

var app = builder.Build();
app.UseRouting();
app.UseAuthentication();
app.UseAuthorization();

app.MapGet("/data", () => Results.Ok(new { message = "Data" })).RequireAuthorization("ReadPolicy");
app.MapPost("/data", (DataModel m) => Results.Created($"/data/{m.Id}", m)).RequireAuthorization("WritePolicy");
app.MapDelete("/data/{id}", (int id) => Results.NoContent()).RequireAuthorization();
app.Run();

public record ScopeRequirement(string Scope) : IAuthorizationRequirement;

public class ScopeHandler : AuthorizationHandler<ScopeRequirement>
{
    protected override Task HandleRequirementAsync(AuthorizationHandlerContext context, ScopeRequirement req)
    {
        var scopes = context.User.FindAll("scope")
            .SelectMany(c => c.Value.Split(' ', StringSplitOptions.RemoveEmptyEntries));
        if (scopes.Contains(req.Scope, StringComparer.Ordinal))
            context.Succeed(req);
        return Task.CompletedTask;
    }
}

public record DataModel(int Id, string Name, string Description);
```

## Space-delimited scopes
`RequireClaim("scope", "api1.read")` only matches if each scope is its own claim. Some issuers emit one claim `"api1.read api1.write"`; the handler above splits every `scope` claim on spaces, so it handles both forms (multiple claims and a single delimited string). Also keep `MapInboundClaims = false` so the claim isn't renamed (otherwise it may appear as `http://schemas.microsoft.com/identity/claims/scope`).
