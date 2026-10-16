The built-in profile schema (`BuiltInSchemas.UserProfile`) contains email (unique, required), name, given_name, family_name, and users log in by `email`. Each access returns a new mutable instance.

## Approach 1: static schema extension (code)
```csharp
var department = new AttributeDefinition
{
    Code = AttributeCode.Create("department"),
    AttributeType = new ScalarAttributeType(ScalarDataType.String),
    Description = AttributeDescription.Create("The department the user belongs to.")
};

builder.Services.AddIdentityServer(o =>
{
    o.UserInteraction.LoginUrl = "/Account/Login";
    o.UserInteraction.LogoutUrl = "/Account/Logout";
})
    .AddStorage(s => s.AddSqlite(o => o.ConnectionString = "Data Source=users.db"))
    .AddUserManagement(_ => { })
    .AddInMemoryDataExtensionSchemas([BuiltInSchemas.UserProfile.Extend(department)]);
```
- `Extend` keeps email/name attributes; it throws `InvalidOperationException` if an attribute/group code already exists. `Extend(attributes, groups)` can add `AttributeGroup`s; use `GroupCode`/`Order` (not unique).
- `OidcStandardAttributes.*` (e.g. `MiddleName`) can be passed too.
- To *replace* instead, register a full `SchemaConfiguration` with `SchemaId.UserProfile`; none of the built-ins remain unless re-added.
- To get `department` into tokens, expose it through a custom identity resource and request that scope.

## Approach 2: runtime editing by admins
Call `AddDynamicSchemas()`, which provides `ISchemaAdmin` (get → modify → `UpdateAsync` with the version for optimistic concurrency).
```csharp
.AddUserManagement(_ => { })
.AddDynamicSchemas();
```
Caveats:
- In dynamic mode, in-memory schemas (including the built-in profile) are **not used or seeded**; `GetAsync(SchemaId.UserProfile)` returns not-found until you create it, so create the initial schema (e.g. seed from `BuiltInSchemas.UserProfile.Extend(department)`) via `ISchemaAdmin` on startup.
- Removing an attribute doesn't purge stored values (validation is on write only).
- `IUserProfileSchemaAdmin` was removed; use `ISchemaAdmin`.
- Secure the admin UI/API, and remember storage schema creation via `MigrateAsync()`.
