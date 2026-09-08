This is a **resource-based authorization** scenario: the decision depends on the specific document being accessed (its `Department` and `OwnerId`), not just on the user's claims in isolation. For that, derive from `AuthorizationHandler<TRequirement, TResource>` and evaluate against the resource passed in, then call `IAuthorizationService.AuthorizeAsync(user, resource, operation)` at the point of use.

Model, operations, and handler:

```csharp
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Authorization.Infrastructure;

// The resource
public record Document
{
    public int Id { get; init; }
    public string Title { get; init; } = "";
    public string Department { get; init; } = "";
    public string OwnerId { get; init; } = "";
}

// Operations expressed as OperationAuthorizationRequirement instances
public static class Operations
{
    public static readonly OperationAuthorizationRequirement Read =
        new() { Name = nameof(Read) };

    public static readonly OperationAuthorizationRequirement Edit =
        new() { Name = nameof(Edit) };
}

// Resource-based handler: note the two type parameters
public class DocumentAuthorizationHandler
    : AuthorizationHandler<OperationAuthorizationRequirement, Document>
{
    protected override Task HandleRequirementAsync(
        AuthorizationHandlerContext context,
        OperationAuthorizationRequirement requirement,
        Document resource)
    {
        if (requirement.Name == Operations.Read.Name)
        {
            // Read: anyone in the same department may read
            if (context.User.HasClaim("department", resource.Department))
            {
                context.Succeed(requirement);
            }
        }
        else if (requirement.Name == Operations.Edit.Name)
        {
            // Edit: only the owner (matched via the 'sub' claim) may edit
            var userId = context.User.FindFirst("sub")?.Value;
            if (userId is not null && userId == resource.OwnerId)
            {
                context.Succeed(requirement);
            }
        }

        // No Succeed() => no opinion; other handlers may still satisfy it.
        return Task.CompletedTask;
    }
}
```

Registration and usage in `Program.cs`:

```csharp
builder.Services.AddSingleton<IAuthorizationHandler, DocumentAuthorizationHandler>();
builder.Services.AddAuthorization();

// ...

app.MapGet("/documents/{id}", async (
    int id,
    ClaimsPrincipal user,
    IAuthorizationService authz) =>
{
    var document = new Document
    {
        Id = id, Title = "Quarterly Report",
        Department = "finance", OwnerId = "user-1"
    };

    var result = await authz.AuthorizeAsync(user, document, Operations.Read);
    return result.Succeeded ? Results.Ok(document) : Results.Forbid();
});

app.MapPut("/documents/{id}", async (
    int id, Document updated,
    ClaimsPrincipal user,
    IAuthorizationService authz) =>
{
    var document = /* load existing */ new Document { Id = id, OwnerId = "user-1" };

    var result = await authz.AuthorizeAsync(user, document, Operations.Edit);
    return result.Succeeded ? Results.NoContent() : Results.Forbid();
});
```

### Why it's structured this way

- **`AuthorizationHandler<OperationAuthorizationRequirement, Document>`** — the second generic parameter is the resource. Resource-based handlers can't run from a `FallbackPolicy`/named policy alone because the resource isn't known until runtime; you invoke them imperatively via `IAuthorizationService.AuthorizeAsync`.
- **`OperationAuthorizationRequirement`** (from `Microsoft.AspNetCore.Authorization.Infrastructure`) is the standard way to model CRUD-style operations. `Operations.Read` / `Operations.Edit` are shared static instances compared by `Name`.
- **Read** checks the user's `department` claim against `resource.Department`; **Edit** compares the `sub` claim to `resource.OwnerId` so only the owner can modify.
- The handler only calls `Succeed()` and never `Fail()`, so it expresses "no opinion" on denial rather than hard-vetoing other potential handlers.
