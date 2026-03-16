# Resource-Based Authorization for Documents

Here's how to implement resource-based authorization for documents using ASP.NET Core.

## Document.cs

```csharp
public class Document
{
    public int Id { get; set; }
    public string Title { get; set; }
    public string Department { get; set; }
    public string OwnerId { get; set; }
}
```

## Operations.cs

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

## DocumentAuthorizationHandler.cs

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
        if (requirement.Name == nameof(Operations.Read))
        {
            var department = context.User.FindFirst("department")?.Value;
            if (department == resource.Department)
            {
                context.Succeed(requirement);
            }
        }
        else if (requirement.Name == nameof(Operations.Edit))
        {
            var userId = context.User.FindFirst("sub")?.Value;
            if (userId == resource.OwnerId)
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

## Usage in Endpoint

```csharp
app.MapGet("/documents/{id}", async (int id, IAuthorizationService authz, HttpContext ctx) =>
{
    var document = new Document { Id = id, Title = "Report", Department = "finance", OwnerId = "user-1" };
    var result = await authz.AuthorizeAsync(ctx.User, document, Operations.Read);
    if (!result.Succeeded) return Results.Forbid();
    return Results.Ok(document);
});
```
