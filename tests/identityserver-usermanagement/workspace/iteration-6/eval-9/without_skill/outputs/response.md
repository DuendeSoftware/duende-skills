I'm unsure of the exact API; verify against the docs.

**Approach 1 – code-defined schema** (at startup):
```csharp
builder.Services.AddUserManagement(o =>
{
    o.Schema.AddAttribute("email", AttributeType.String);   // keep built-ins
    o.Schema.AddAttribute("name", AttributeType.String);
    o.Schema.AddAttribute("department", AttributeType.String);
});
```
Schema changes require a redeploy; map `department` to a claim via a profile service/IdentityResource.

**Approach 2 – runtime-editable schema:** store the schema in the database and expose an admin API/UI (using the User Management schema management API) that adds/changes attributes with validation, authorisation restricted to admins. Don't remove attributes that have data without a migration plan; cache and invalidate schema on change.
