Use a **data extension schema** with `ExtendedProperties` (Duende Storage, preview). Defining the schema in code means the in-memory schema store, which is the safer default: it changes via deployment and is identical on all nodes. **No SQL migration is needed**, since values are stored as generic attribute-value data.

```csharp
using Duende.Storage.EntityAttributeValue;
using Duende.Storage.Schema;

var costCenter = new TypedAttributeDefinition<int>(
    AttributeCode.Create("cost_center"),
    new ScalarAttributeType(ScalarDataType.Integer));

var clientSchema = new SchemaConfiguration
{
    SchemaId = SchemaId.Client,
    AttributeDefinitions = [costCenter]
};

builder.Services.AddIdentityServer()
    .AddStorage(s => s.AddSqlite(o => o.ConnectionString = conn))
    .AddConfigurationStorage()
    .AddOperationalStorage()
    .AddInMemoryDataExtensionSchemas([clientSchema]);
```
(Exact type/enum names may differ slightly in the preview. Check `ScalarDataType` members.)

## Writing via the admin API
```csharp
var ext = new AttributeValueCollection();
ext.Set(costCenter, 4210);

var result = await clientAdmin.CreateAsync(new CreateClient
{
    ClientId = "billing-web",
    AllowedGrantTypes = ["authorization_code"],
    AllowedScopes = ["openid"],
    ExtendedProperties = ext
}, ct);
if (!result.IsSuccess) throw new InvalidOperationException(string.Join("; ", result.Errors));
```
The admin API rejects unknown properties, wrong types, missing required values, and duplicates for unique attributes. Update with get, modify, then `UpdateAsync(id, item, expectedVersion, ct)` for optimistic concurrency.

## Caveats
- **Don't combine with `AddDynamicSchemas()`**: `AddInMemoryDataExtensionSchemas` has no effect then, and the DB becomes the only source of schemas.
- `AddInMemoryDataExtensionSchemas` doesn't register `ISchemaStore`/`ISchemaAdmin`. If you want runtime schema editing, use `AddDynamicSchemas()` instead and create the schema through `ISchemaAdmin`.
- Only set `IsQueryable` if you need to filter/sort by `cost_center`, since it adds indexing cost.
- Renaming, removing, retyping or making the attribute required later is a contract change. Plan it.
- `SchemaId.Client` allows one schema per ID, so put all your client attributes in the same `SchemaConfiguration`.
