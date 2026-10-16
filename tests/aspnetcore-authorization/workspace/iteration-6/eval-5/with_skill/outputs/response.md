## Operations, Document, and handler

```csharp
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Authorization.Infrastructure;

public static class Operations
{
    public static readonly OperationAuthorizationRequirement Read = new() { Name = nameof(Read) };
    public static readonly OperationAuthorizationRequirement Edit = new() { Name = nameof(Edit) };
}

public class Document
{
    public int Id { get; set; }
    public string Title { get; set; } = "";
    public string Department { get; set; } = "";
    public string OwnerId { get; set; } = "";
}

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
                context.Succeed(requirement);
        }
        else if (requirement == Operations.Edit)
        {
            // Only the owner can edit
            if (userId is not null && resource.OwnerId == userId)
                context.Succeed(requirement);
        }

        // No Fail(): not succeeding just means "no opinion"
        return Task.CompletedTask;
    }
}
```

## Registration and usage

```csharp
builder.Services.AddSingleton<IAuthorizationHandler, DocumentAuthorizationHandler>();
builder.Services.AddAuthorization();

app.UseAuthentication();
app.UseAuthorization();

app.MapGet("/documents/{id}", async (int id, ClaimsPrincipal user, IAuthorizationService authz) =>
{
    var doc = new Document { Id = id, Title = "Quarterly Report", Department = "finance", OwnerId = "user-1" };

    var result = await authz.AuthorizeAsync(user, doc, Operations.Read);
    return result.Succeeded ? Results.Ok(doc) : Results.Forbid();
}).RequireAuthorization();

app.MapPut("/documents/{id}", async (int id, object body, ClaimsPrincipal user, IAuthorizationService authz) =>
{
    var doc = new Document { Id = id, Title = "Quarterly Report", Department = "finance", OwnerId = "user-1" };

    var result = await authz.AuthorizeAsync(user, doc, Operations.Edit);
    return result.Succeeded ? Results.NoContent() : Results.Forbid();
}).RequireAuthorization();
```

Why imperative: the decision depends on the loaded resource's `Department` and `OwnerId`, which a declarative policy can't see. The handler must be registered in DI, otherwise every check silently denies. Handlers use `Succeed()` only and never `Fail()`, so other handlers (for example an admin override) can still grant access.
