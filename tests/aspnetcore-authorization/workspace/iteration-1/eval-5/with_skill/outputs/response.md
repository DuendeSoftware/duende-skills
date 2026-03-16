# Resource-Based Authorization for Documents

When authorization decisions depend on the resource being accessed, use `IAuthorizationService` with `OperationAuthorizationRequirement`. This pattern lets you check properties of the specific resource (like department or owner) against the current user's claims.

## Document.cs

```csharp
public record Document(int Id, string Title, string Department, string OwnerId);
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
        if (requirement == Operations.Read)
        {
            // Anyone in the same department can read the document
            var userDepartment = context.User.FindFirst("department")?.Value;
            if (userDepartment == resource.Department)
            {
                context.Succeed(requirement);
            }
        }
        else if (requirement == Operations.Edit)
        {
            // Only the document owner can edit
            var userId = context.User.FindFirst("sub")?.Value;
            if (userId == resource.OwnerId)
            {
                context.Succeed(requirement);
            }
        }

        // Do NOT call context.Fail() — simply not calling Succeed() means
        // "I have no opinion" and allows other handlers to try.
        return Task.CompletedTask;
    }
}
```

## Updated Program.cs

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

// Register the document authorization handler
builder.Services.AddSingleton<IAuthorizationHandler, DocumentAuthorizationHandler>();

builder.Services.AddAuthorization();

var app = builder.Build();

app.UseAuthentication();
app.UseAuthorization();

// Products endpoints
app.MapGet("/products", () => Results.Ok(new[]
{
    new { Id = 1, Name = "Widget", Price = 9.99 },
    new { Id = 2, Name = "Gadget", Price = 19.99 }
}));

app.MapPost("/products", (object product) => Results.Created("/products/3", product));
app.MapDelete("/products/{id}", (int id) => Results.NoContent());

// Admin endpoints
app.MapGet("/admin/users", () => Results.Ok(new[] { "alice", "bob" }));
app.MapPost("/admin/users", (object user) => Results.Created("/admin/users/3", user));

// Documents — resource-based authorization
app.MapGet("/documents/{id}", async (int id, IAuthorizationService authz, HttpContext httpContext) =>
{
    // In a real app, fetch from database
    var document = new Document(id, "Quarterly Report", "finance", "user-1");

    var result = await authz.AuthorizeAsync(httpContext.User, document, Operations.Read);
    if (!result.Succeeded) return Results.Forbid();

    return Results.Ok(document);
});

app.MapPut("/documents/{id}", async (int id, object doc, IAuthorizationService authz, HttpContext httpContext) =>
{
    var document = new Document(id, "Quarterly Report", "finance", "user-1");

    var result = await authz.AuthorizeAsync(httpContext.User, document, Operations.Edit);
    if (!result.Succeeded) return Results.Forbid();

    return Results.NoContent();
});

// Health check
app.MapGet("/health", () => Results.Ok("healthy"));

app.Run();
```

## How It Works

1. **`Document` record** holds the resource properties — `Department` and `OwnerId` — needed for authorization decisions.
2. **`Operations` class** defines static `OperationAuthorizationRequirement` fields (`Read` and `Edit`) that identify the type of operation being performed.
3. **`DocumentAuthorizationHandler`** extends `AuthorizationHandler<OperationAuthorizationRequirement, Document>` — the two-generic-parameter version that receives both the requirement and the resource.
4. **Read operation** checks the user's `department` claim against `resource.Department` — users in the same department can read.
5. **Edit operation** checks the user's `sub` claim against `resource.OwnerId` — only the owner can edit.
6. **`IAuthorizationService.AuthorizeAsync`** is called in the endpoint handler, passing the `ClaimsPrincipal`, the `Document` resource, and the `OperationAuthorizationRequirement`. The framework routes this to the registered handler.
