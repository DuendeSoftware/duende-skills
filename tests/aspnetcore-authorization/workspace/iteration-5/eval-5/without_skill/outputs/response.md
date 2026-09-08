Because the decision depends on the actual document being accessed, this is resource-based authorization. You implement a handler that derives from `AuthorizationHandler<TRequirement, TResource>` where the resource is the `Document`, and you evaluate it at runtime with `IAuthorizationService.AuthorizeAsync(user, resource, operation)`.

```csharp
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Authorization.Infrastructure;

public class Document
{
    public int Id { get; set; }
    public string Title { get; set; } = "";
    public string Department { get; set; } = "";
    public string OwnerId { get; set; } = "";
}

public static class Operations
{
    public static OperationAuthorizationRequirement Read =
        new() { Name = nameof(Read) };
    public static OperationAuthorizationRequirement Edit =
        new() { Name = nameof(Edit) };
}

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
                context.Succeed(requirement);
        }
        else if (requirement.Name == Operations.Edit.Name)
        {
            var sub = context.User.FindFirst("sub")?.Value;
            if (sub == resource.OwnerId)
                context.Succeed(requirement);
        }

        return Task.CompletedTask;
    }
}
```

Register the handler and use it:

```csharp
builder.Services.AddSingleton<IAuthorizationHandler, DocumentAuthorizationHandler>();
builder.Services.AddAuthorization();

app.MapGet("/documents/{id}", async (
    int id, ClaimsPrincipal user, IAuthorizationService authz) =>
{
    var doc = new Document { Id = id, Department = "finance", OwnerId = "user-1" };
    var result = await authz.AuthorizeAsync(user, doc, Operations.Read);
    return result.Succeeded ? Results.Ok(doc) : Results.Forbid();
});

app.MapPut("/documents/{id}", async (
    int id, ClaimsPrincipal user, IAuthorizationService authz) =>
{
    var doc = new Document { Id = id, OwnerId = "user-1" };
    var result = await authz.AuthorizeAsync(user, doc, Operations.Edit);
    return result.Succeeded ? Results.NoContent() : Results.Forbid();
});
```

Key points:

- `Document` holds `Department` and `OwnerId`.
- `Operations` exposes static `Read` and `Edit` as `OperationAuthorizationRequirement`.
- `DocumentAuthorizationHandler` extends `AuthorizationHandler<OperationAuthorizationRequirement, Document>`.
- Read succeeds when the user's `department` claim equals the document's `Department`; Edit succeeds when the user's `sub` claim equals the document's `OwnerId`.
- Register the handler in DI and call `IAuthorizationService.AuthorizeAsync` per request with the loaded resource.
