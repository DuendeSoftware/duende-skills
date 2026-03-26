# Resource-Based Authorization for Documents

For resource-based authorization, you need a handler that can inspect the actual resource to make access decisions. Here's how to implement it.

## Document Model

```csharp
public class Document
{
    public int Id { get; set; }
    public string Title { get; set; }
    public string Department { get; set; }
    public string OwnerId { get; set; }
}
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
        if (requirement.Name == Operations.Read.Name)
        {
            if (context.User.HasClaim("department", resource.Department))
            {
                context.Succeed(requirement);
            }
        }
        else if (requirement.Name == Operations.Edit.Name)
        {
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

Then in your endpoints, inject `IAuthorizationService` and call `AuthorizeAsync` with the resource and the operation:

```csharp
var result = await authorizationService.AuthorizeAsync(User, document, Operations.Read);
if (!result.Succeeded) return Results.Forbid();
```

The handler checks the operation name and applies the appropriate logic - department matching for reads, owner matching for edits.
