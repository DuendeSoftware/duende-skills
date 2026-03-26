# Resource-Based Authorization for Documents

Resource-based authorization is needed when the access decision depends on the specific resource being accessed. For your document scenario, you need to check the user's department for reads and the user's identity (sub claim) for edits.

## Document Model

```csharp
public record Document(int Id, string Title, string Department, string OwnerId);
```

## Operations Class

```csharp
using Microsoft.AspNetCore.Authorization.Infrastructure;

public static class Operations
{
    public static readonly OperationAuthorizationRequirement Read =
        new() { Name = nameof(Read) };
    public static readonly OperationAuthorizationRequirement Edit =
        new() { Name = nameof(Edit) };
}
```

The `OperationAuthorizationRequirement` is a built-in type from `Microsoft.AspNetCore.Authorization.Infrastructure` that carries a `Name` property. By using `static readonly` fields, you get reusable, well-known operation constants.

## DocumentAuthorizationHandler

```csharp
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Authorization.Infrastructure;

public class DocumentAuthorizationHandler
    : AuthorizationHandler<OperationAuthorizationRequirement, Document>
{
    protected override Task HandleRequirementAsync(
        AuthorizationHandlerContext context,
        OperationAuthorizationRequirement requirement,
        Document resource)
    {
        var userId = context.User.FindFirst("sub")?.Value;

        if (requirement == Operations.Read)
        {
            // Anyone in the same department can read
            if (context.User.HasClaim("department", resource.Department))
            {
                context.Succeed(requirement);
            }
        }
        else if (requirement == Operations.Edit)
        {
            // Only the owner can edit
            if (resource.OwnerId == userId)
            {
                context.Succeed(requirement);
            }
        }

        return Task.CompletedTask;
    }
}
```

### Key Design Points

1. **`AuthorizationHandler<OperationAuthorizationRequirement, Document>`** — The two generic parameters indicate that this handler evaluates `OperationAuthorizationRequirement` against a `Document` resource. The authorization system will only invoke this handler when both types match.

2. **Read: Department check** — `context.User.HasClaim("department", resource.Department)` checks whether the authenticated user has a `department` claim matching the document's `Department` property. This implements department-level read access.

3. **Edit: Owner check** — `resource.OwnerId == userId` compares the `sub` claim (the user's unique identifier from the identity token) against the document's `OwnerId`. Only the document owner can edit.

4. **No `context.Fail()` call** — Following the pattern from the skill reference, the handler only calls `Succeed()` when conditions are met. Not calling `Succeed()` means "no opinion", allowing other handlers to potentially satisfy the requirement.

## Registration and Usage

```csharp
// In Program.cs — register the handler
builder.Services.AddSingleton<IAuthorizationHandler, DocumentAuthorizationHandler>();

// In an endpoint or controller — use IAuthorizationService
app.MapGet("/documents/{id}", async (int id, IAuthorizationService authz, HttpContext http) =>
{
    // In a real app, fetch from a repository
    var document = new Document(id, "Quarterly Report", "finance", "user-1");

    var result = await authz.AuthorizeAsync(
        http.User,
        document,
        Operations.Read);

    if (!result.Succeeded) return Results.Forbid();

    return Results.Ok(document);
});

app.MapPut("/documents/{id}", async (int id, object doc, IAuthorizationService authz, HttpContext http) =>
{
    var document = new Document(id, "Quarterly Report", "finance", "user-1");

    var result = await authz.AuthorizeAsync(
        http.User,
        document,
        Operations.Edit);

    if (!result.Succeeded) return Results.Forbid();

    return Results.NoContent();
});
```

The `IAuthorizationService.AuthorizeAsync` method takes the user principal, the resource, and the operation requirement. It finds all registered handlers that match the requirement+resource types and evaluates them.
