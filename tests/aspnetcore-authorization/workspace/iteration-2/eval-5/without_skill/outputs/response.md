# Resource-Based Authorization for Documents

You can implement resource-based authorization using ASP.NET Core's authorization handlers. Here's a setup with a Document model, operations, and a handler.

## Document Model

```csharp
public class Document
{
    public int Id { get; set; }
    public string Title { get; set; } = string.Empty;
    public string Department { get; set; } = string.Empty;
    public string OwnerId { get; set; } = string.Empty;
}
```

## Operations

```csharp
using Microsoft.AspNetCore.Authorization.Infrastructure;

public static class Operations
{
    public static readonly OperationAuthorizationRequirement Read = new() { Name = nameof(Read) };
    public static readonly OperationAuthorizationRequirement Edit = new() { Name = nameof(Edit) };
}
```

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
        if (requirement == Operations.Read)
        {
            // Check if user is in the same department
            var userDepartment = context.User.FindFirst("department")?.Value;
            if (userDepartment == resource.Department)
            {
                context.Succeed(requirement);
            }
        }
        else if (requirement == Operations.Edit)
        {
            // Check if user is the owner
            var userId = context.User.FindFirst("sub")?.Value;
            if (resource.OwnerId == userId)
            {
                context.Succeed(requirement);
            }
        }

        return Task.CompletedTask;
    }
}
```

## Registration

```csharp
builder.Services.AddSingleton<IAuthorizationHandler, DocumentAuthorizationHandler>();
```

## Notes

- The handler checks the `department` claim for reads and the `sub` claim for edits.
- `OperationAuthorizationRequirement` is the built-in ASP.NET Core type for operation-based authorization.
- You use `IAuthorizationService.AuthorizeAsync(user, resource, operation)` in your endpoints to trigger the handler.
