```csharp
using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Authorization.Infrastructure;

public static class Operations
{
    public static readonly OperationAuthorizationRequirement Read =
        new() { Name = nameof(Read) };
    public static readonly OperationAuthorizationRequirement Edit =
        new() { Name = nameof(Edit) };
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
        Document document)
    {
        if (requirement.Name == Operations.Read.Name)
        {
            var dept = context.User.FindFirstValue("department");
            if (dept is not null &&
                string.Equals(dept, document.Department, StringComparison.OrdinalIgnoreCase))
            {
                context.Succeed(requirement);
            }
        }
        else if (requirement.Name == Operations.Edit.Name)
        {
            var sub = context.User.FindFirstValue("sub")
                      ?? context.User.FindFirstValue(ClaimTypes.NameIdentifier);
            if (sub is not null && sub == document.OwnerId)
            {
                context.Succeed(requirement);
            }
        }

        return Task.CompletedTask;
    }
}
```

Registration and use:

```csharp
builder.Services.AddSingleton<IAuthorizationHandler, DocumentAuthorizationHandler>();
builder.Services.AddAuthorization();

app.UseAuthentication();
app.UseAuthorization();

app.MapGet("/documents/{id}", async (int id, ClaimsPrincipal user, IAuthorizationService auth) =>
{
    var doc = new Document { Id = id, Title = "Quarterly Report", Department = "finance", OwnerId = "user-1" };
    var result = await auth.AuthorizeAsync(user, doc, Operations.Read);
    return result.Succeeded ? Results.Ok(doc) : Results.Forbid();
}).RequireAuthorization();

app.MapPut("/documents/{id}", async (int id, Document updated, ClaimsPrincipal user, IAuthorizationService auth) =>
{
    var existing = new Document { Id = id, Title = "Quarterly Report", Department = "finance", OwnerId = "user-1" };
    var result = await auth.AuthorizeAsync(user, existing, Operations.Edit);
    return result.Succeeded ? Results.NoContent() : Results.Forbid();
}).RequireAuthorization();
```

Resource-based authorization needs the resource loaded first, so it is called imperatively through `IAuthorizationService` rather than with an attribute. The handler never calls `Fail()`, so other handlers can still grant access. Note that the `sub` claim may be remapped to `ClaimTypes.NameIdentifier` by the default inbound claim mapping, hence the fallback.
