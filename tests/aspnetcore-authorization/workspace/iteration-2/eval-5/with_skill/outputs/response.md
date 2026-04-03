# Resource-Based Authorization for Documents

Resource-based authorization is used when access decisions depend on the specific resource being accessed. Use `IAuthorizationService` with `OperationAuthorizationRequirement` and a custom handler.

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

## Operations Class

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

## Registration and Usage in `Program.cs`

```csharp
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Authorization;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(options =>
    {
        options.Authority = builder.Configuration["Authentication:Authority"];
        options.Audience = builder.Configuration["Authentication:Audience"];
    });

builder.Services.AddAuthorization();
builder.Services.AddSingleton<IAuthorizationHandler, DocumentAuthorizationHandler>();

var app = builder.Build();

app.UseAuthentication();
app.UseAuthorization();

// Resource-based authorization — read
app.MapGet("/documents/{id}", async (int id, IAuthorizationService authz, HttpContext httpContext) =>
{
    var document = new Document
    {
        Id = id,
        Title = "Quarterly Report",
        Department = "finance",
        OwnerId = "user-1"
    };

    var result = await authz.AuthorizeAsync(httpContext.User, document, Operations.Read);
    if (!result.Succeeded) return Results.Forbid();

    return Results.Ok(document);
});

// Resource-based authorization — edit
app.MapPut("/documents/{id}", async (int id, object doc, IAuthorizationService authz, HttpContext httpContext) =>
{
    var document = new Document
    {
        Id = id,
        Title = "Quarterly Report",
        Department = "finance",
        OwnerId = "user-1"
    };

    var result = await authz.AuthorizeAsync(httpContext.User, document, Operations.Edit);
    if (!result.Succeeded) return Results.Forbid();

    return Results.NoContent();
});

app.MapGet("/health", () => Results.Ok("healthy"));

app.Run();
```

## Key Concepts

- **`DocumentAuthorizationHandler`** extends `AuthorizationHandler<OperationAuthorizationRequirement, Document>` — the second type parameter is the resource type, enabling resource-specific authorization logic.
- The **Read** operation checks the user's `department` claim against the document's `Department` property — users in the same department can read.
- The **Edit** operation checks the user's `sub` claim against the document's `OwnerId` — only the owner can edit.
- **`Operations`** is a static class with `OperationAuthorizationRequirement` fields for `Read` and `Edit`, following the standard ASP.NET Core pattern.
- At the endpoint level, `IAuthorizationService.AuthorizeAsync` is called with the user, the resource, and the operation to perform the resource-based check.
