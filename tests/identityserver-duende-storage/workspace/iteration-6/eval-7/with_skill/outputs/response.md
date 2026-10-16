**Cause:** with `AddDynamicSchemas()` the **database is the only source of schemas**. `AddSamlDynamicProvider()` registers the `idp:saml` schema as an *in-memory* schema, and that is not used and not seeded once dynamic schemas are enabled. So the stored schema store has no `idp:saml` schema, and a SAML IdP with `ExtendedProperties` fails validation. Creating SAML IdPs with extended properties still requires `AddSamlDynamicProvider()`, but that alone isn't enough here. The same applies to `AddOidcDynamicProvider()` and `idp:oidc`. `AddInMemoryDataExtensionSchemas` likewise has no effect.

**Fix:** create the schema in the database through `ISchemaAdmin`, once, from a single deployment process (to avoid races), e.g. a hosted service at startup:

```csharp
using Duende.IdentityServer.Stores.Storage.IdentityProviders;
using Duende.Storage.EntityAttributeValue;
using Duende.Storage.Schema;

public class SchemaSeeder(ISchemaAdmin schemaAdmin) : IHostedService
{
    public async Task StartAsync(CancellationToken ct)
    {
        var result = await schemaAdmin.CreateAsync(BuiltInSchemas.SamlProvider, ct);
        if (!result.IsSuccess)
            throw new InvalidOperationException(string.Join("; ", result.Errors));
    }
    public Task StopAsync(CancellationToken ct) => Task.CompletedTask;
}

builder.Services.AddHostedService<SchemaSeeder>();
```
`SchemaId.SamlIdentityProvider` is `"idp:saml"`. If the schema already exists on later startups, the create fails, so check for existence first (a get on the schema) rather than throwing every time, or run it as a one-off deployment step.

**Extending it:** `BuiltInSchemas.SamlProvider` returns a fresh mutable instance each time, so add your own attributes before creating it:
```csharp
var schema = BuiltInSchemas.SamlProvider.Extend(myAttribute); // throws if the code already exists
await schemaAdmin.CreateAsync(schema, ct);
```
Later changes follow get, modify, then `UpdateAsync(schemaId, schema, version, ct)`.

**Options:** if admins don't actually need to edit schemas at runtime, drop `AddDynamicSchemas()` and use `AddInMemoryDataExtensionSchemas([...])`, which is the safer default (schemas in code, identical on all nodes). Keep `AddSamlDynamicProvider()` either way.
