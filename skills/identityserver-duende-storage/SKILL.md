---
name: identityserver-duende-storage
description: "Duende Storage (preview) persistence provider for IdentityServer: AddStorage with SQL Server/PostgreSQL/Oracle/SQLite, AddConfigurationStorage/AddOperationalStorage, multiple storage instances, configuration admin APIs (IClientAdmin etc.), data extension schemas, schema migration/CLI, purge options, sharing with User Management, and migrating from Entity Framework Core."
invocable: false
---

# Duende Storage (Preview)

## When to Use This Skill

- Choosing Duende Storage vs Entity Framework Core vs in-memory vs custom stores
- Registering `AddStorage(...)`, `AddConfigurationStorage()`, `AddOperationalStorage()`
- Creating/updating clients, scopes, resources and dynamic providers through admin service APIs
- Adding schema-validated custom properties (data extension schemas) to clients/resources/providers
- Routing configuration / operational / User Management data to separate databases (storage instances)
- Deploying/migrating the Duende Storage schema (including the Duende CLI)
- Planning a migration from EF Core stores

## Core Principles

- **Preview**: packages (`--prerelease`), APIs, schemas and behavior may change before GA. Introduced with IdentityServer 8.1 previews.
- **Opt-in, does not replace EF Core.** The EF Core provider (classic tables) stays fully supported. Adopt Duende Storage only for what it adds: supported admin APIs, schema-validated custom properties, consistent querying + optimistic concurrency across databases, storage pools (for Spaces), shared persistence across Duende products (e.g. User Management).
- **`AddStorage(...)` only selects a database provider for an instance.** It does not store anything by itself. Call `AddConfigurationStorage()` and `AddOperationalStorage()` to route data categories to it.
- Store interfaces (`IClientStore`, `IResourceStore`, …) are unchanged: the runtime keeps using the same abstractions.
- Docs: https://docs.duendesoftware.com/identityserver/data/providers/duende-storage/

## Packages

| Database | Package | Registration |
|----------|---------|--------------|
| SQL Server | `Duende.Storage.MsSql` | `AddMsSql` |
| PostgreSQL | `Duende.Storage.PostgreSql` | `AddPostgreSql` |
| Oracle | `Duende.Storage.Oracle` | `AddOracle` |
| SQLite | `Duende.Storage.Sqlite` | `AddSqlite` (`AddSqliteInMemory` for tests) |

```bash
dotnet add package Duende.IdentityServer --prerelease
dotnet add package Duende.Storage.Sqlite --prerelease
```

## Registration

```csharp
// Program.cs
using Duende.IdentityServer;
using Duende.Storage.Schema;
using Duende.Storage.Sqlite;

builder.Services
    .AddIdentityServer()
    .AddStorage(storage =>
        storage.AddSqlite(options =>
            options.ConnectionString =
                builder.Configuration.GetConnectionString("IdentityServer")
                ?? throw new InvalidOperationException("IdentityServer connection string is missing.")))
    .AddConfigurationStorage()
    .AddOperationalStorage();

var app = builder.Build();
if (app.Environment.IsDevelopment())
{
    await app.Services.GetRequiredService<IStorageInstanceSchema>().MigrateAsync(CancellationToken.None);
}
app.UseIdentityServer();
```

- `AddConfigurationStorage()` registers `IClientStore`, `IResourceStore`, `IIdentityProviderStore`, `ISamlServiceProviderStore`, `ICorsPolicyService` **and** the configuration admin APIs.
- `AddOperationalStorage()` registers `IPersistedGrantStore`, `IDeviceFlowStore`, `IPushedAuthorizationRequestStore`, `IServerSideSessionStore`, `ISigningKeyStore`, `ISamlSigninStateStore`, `ISamlLogoutSessionStore`. Still call `AddServerSideSessions()` separately to enable server-side sessions.
- Override a single store by registering it **after**: `.AddConfigurationStorage().AddOperationalStorage().AddInMemoryClients(clients)` replaces only the client store.
- SQL Server/PostgreSQL/Oracle use provider-native connection factory / data source registrations (e.g. `NpgsqlDataSource`, `CreateSqlConnection`). Keep credentials in a secret store.

### Purge

A background purge service runs against **every** registered storage instance: enabled by default, hourly, `BatchSize` 100, fuzzed start. Configure `StoragePurgeOptions` (`PurgeInterval`, `BatchSize`, `EnablePurge = false` when an external job owns cleanup) via `builder.Services.Configure<StoragePurgeOptions>(...)` before `AddOperationalStorage()`.

## Schema Deployment

- `IStorageInstanceSchema.MigrateAsync` creates/upgrades the common schema; needs DDL permissions. Fine in development; in production run it as a controlled deployment step so the runtime identity can have narrower permissions. Run only one migration process at a time; after migrating it verifies the DB matches the expected schema.
- `Duende.Cli` (preview): `dotnet tool install --global Duende.Cli --prerelease`, then `duende storage migrate --provider mssql --dry-run` then without `--dry-run`. Connection string via `DUENDE_STORAGE_CONNECTION_STRING`. Providers: `mssql`, `postgresql`, `sqlite` (add `--schema` for non-default SQL Server/PostgreSQL schema). It downloads/caches `Duende.Storage.CliPlugin` from NuGet on first use. **Oracle is not supported by the CLI**: use `IStorageInstanceSchema.BuildMigrationScript` and have a DBA apply the SQL.
- Never hide a missing connection string or continue after a migration failure.

## Multiple Storage Instances

A *data category* (`configuration`, `operational`, `dynamic-schemas`, `user-management`) maps to a *storage instance* (`StorageInstanceId`) via `IStorageInstanceRouter`. Unmapped categories fall back to `StorageInstanceId.Default`.

| Method | Category |
|--------|----------|
| `AddConfigurationStorage(...)` | `configuration` |
| `AddOperationalStorage(...)` | `operational` |
| `AddDynamicSchemas(...)` | `dynamic-schemas` |
| `AddUserManagement(...)` | `user-management` |

```csharp
var operationalInstanceId = StorageInstanceId.Create("operational");

builder.Services.AddIdentityServer()
    .AddStorage(storage => storage.AddSqlite(o => o.ConnectionString = configConn))          // default instance
    .AddConfigurationStorage()
    .AddStorage(operationalInstanceId, storage => storage.AddSqlite(o => o.ConnectionString = opsConn))
    .AddOperationalStorage(operationalInstanceId);

// Migrate EVERY instance
var factory = app.Services.GetRequiredService<IStorageInstanceSchemaFactory>();
await (await factory.GetStorageInstanceSchema(StorageInstanceId.Default, ct)).MigrateAsync(ct);
await (await factory.GetStorageInstanceSchema(operationalInstanceId, ct)).MigrateAsync(ct);
```

Rules:
- Each category maps to **one** instance per application; mapping it twice to different instances (even from different products) throws `InvalidOperationException`. Selecting a second provider for the same instance also throws.
- `IStorageInstanceSchema.MigrateAsync` only migrates the default instance; use `IStorageInstanceSchemaFactory.GetStorageInstanceSchema(id, ct)` for named instances. The CLI migrates one connection string at a time, so run it per instance.
- Outbox processing and purge are registered once and discover every instance automatically.
- With Spaces, every category resolves to its mapped instance first, then to the space's pool within that instance.

## Configuration Admin APIs

`AddConfigurationStorage()` registers .NET service APIs (not HTTP endpoints). You expose them behind your own authenticated/authorized/audited admin app, CLI or deployment process.

| Service | Manages |
|---------|---------|
| `IClientAdmin` | Clients incl. secrets |
| `IApiScopeAdmin` | API scopes |
| `IApiResourceAdmin` | API resources, scope relationships, API secrets |
| `IIdentityResourceAdmin` | Identity resources |
| `IIdentityProviderAdmin` | Dynamic identity providers |
| `ISamlServiceProviderAdmin` | SAML service providers |

Create referenced scopes before the resources/clients that use them.

```csharp
using Duende.IdentityServer.Admin;
using Duende.IdentityServer.Admin.Clients;

SaveResult<Guid> result = await clientAdmin.CreateAsync(new CreateClient
{
    ClientId = "inventory-worker",
    ClientName = "Inventory worker",
    AllowedGrantTypes = ["client_credentials"],
    AllowedScopes = ["inventory.read"],
    ClientSecrets = [ new CreateClientSecret { PlaintextValue = secretFromVault } ]
}, ct);
```

Other model types: `ApiScopeConfiguration` (`Name`, `DisplayName`), `ApiResourceConfiguration` (`Scopes`), `IdentityResourceConfiguration` (`UserClaims`), `IdentityProviderConfiguration` (`Scheme`, `Type`, `Properties`), `SamlServiceProviderConfiguration` (`EntityId`, `AssertionConsumerServiceUrls` of `SamlIndexedEndpointConfiguration`).

- Results: create/update/delete return `SaveResult<TId>` (check `IsSuccess`; `Id`, `Version`, `Errors`); get returns `GetResult<T>` (`Found`, `Item`, `Version`).
- **Optimistic concurrency**: `UpdateAsync(id, item, expectedVersion, ct)` requires the version from the preceding get/create. Handle validation, duplicate-name, not-found, version-conflict errors.
- `QueryAsync(QueryRequest.Create<ApiScopeFilter, ApiScopeSortField>(new ApiScopeFilter { Name = "inventory" }), ct)` — filters can be *contains* matches, so compare business identifiers exactly; page via continuation tokens on `QueryResult<T>`. `DeleteAsync(id, ct)`.
- Client and API secrets are **hashed** on write (plaintext in, never returned). **Dynamic identity provider properties (e.g. `ClientSecret`) are stored recoverably — not hashed, not field-encrypted.** Use encrypted connections, encryption at rest, restricted DB access and protected backups. **Do not grant direct read access to the configuration store as a substitute for an authorized admin API** — go through the admin API (e.g. `IIdentityProviderAdmin`) with proper authorization.
- Register the matching dynamic provider type (`AddOidcDynamicProvider()` / `AddSamlDynamicProvider()`) for IdPs you create.

## Data Extension Schemas

Add typed custom properties (`ExtendedProperties`) to clients, API resources, API scopes, identity resources, dynamic IdPs and SAML SPs without DB schema changes.

**No SQL migrations are needed when adding or changing extension schemas or attributes**: values are stored as generic attribute-value data, so only the schema definition changes. Values that are unknown to the schema or of the wrong type are rejected on write.

| Schema store | Choose when |
|--------------|-------------|
| In-memory: `AddInMemoryDataExtensionSchemas([...])` | Schemas live in code, change via deployment, identical on all nodes (safer default) |
| Storage-backed: `AddDynamicSchemas()` (`ISchemaStore` + `ISchemaAdmin`) | Admin system changes schemas at runtime |

```csharp
var department = new TypedAttributeDefinition<string>(AttributeCode.Create("department"), new ScalarAttributeType(ScalarDataType.String));
var schema = new SchemaConfiguration { SchemaId = SchemaId.Client, AttributeDefinitions = [department] };
builder.Services.AddIdentityServer().AddStorage(...).AddInMemoryDataExtensionSchemas([schema]);

var ext = new AttributeValueCollection();
ext.Set(department, "Sales");
await clientAdmin.CreateAsync(new CreateClient { ClientId = "sales", AllowedGrantTypes = ["client_credentials"], ExtendedProperties = ext }, ct);
```

- `SchemaId.Client | ApiResource | ApiScope | IdentityResource | SamlServiceProvider | OidcIdentityProvider ("idp:oidc") | SamlIdentityProvider ("idp:saml") | UserProfile`; custom IdP types: `SchemaId.BuildIdentityProviderId(type)`. One schema per ID.
- Admin API rejects unknown properties, wrong types, missing required values, duplicates for unique attributes. `IsQueryable` adds indexing cost — only for filter/sort needs. Renaming/removing/retyping/making required is a contract change.
- `AddInMemoryDataExtensionSchemas` does **not** register `ISchemaStore`/`ISchemaAdmin` and has no effect once `AddDynamicSchemas()` is used. With `AddDynamicSchemas()` the DB is the only source: in-memory built-ins are not used and not seeded (create via `ISchemaAdmin.CreateAsync(BuiltInSchemas.SamlProvider, ct)` and check `result.IsSuccess`, otherwise throw using `result.Errors`; e.g. in an `IHostedService` at startup, using `Duende.IdentityServer.Stores.Storage.IdentityProviders` / `Duende.Storage.EntityAttributeValue`; `SchemaId.SamlIdentityProvider` = `"idp:saml"`). Update with get → modify → `UpdateAsync(schemaId, schema, version, ct)`. Provision from one deployment process to avoid races.
- **Built-in schemas** (`BuiltInSchemas.OidcProvider`, `.SamlProvider`, `.UserProfile`) return a fresh mutable instance on each access. Extend with `BuiltInSchemas.OidcProvider.Extend(attr)` (throws if the code already exists) or register a full replacement `SchemaConfiguration` with the same `SchemaId` (wins regardless of registration order; last registered wins; none of the built-in attributes remain implicitly).
- `AddOidcDynamicProvider()` / `AddSamlDynamicProvider()` register the `idp:oidc` / `idp:saml` schema; creating SAML IdPs with `ExtendedProperties` **requires** `AddSamlDynamicProvider()`.
- SAML SP extensions are **admin-only metadata**: not projected to the runtime `SamlServiceProvider`; don't use them for SAML protocol processing.
- `IUserProfileSchemaAdmin` was removed; use `ISchemaAdmin`.

## Sharing With Duende User Management

Call `AddUserManagement(...)` **without** registering the provider again — it maps `user-management` to the default instance and reuses its DB. Use `AddUserManagement(userManagementInstanceId, configure)` plus `AddStorage(userManagementInstanceId, ...)` for a dedicated DB. With Spaces, User Management data is space-routed by default (profiles, authenticators, roles, groups per space); there is no per-product opt-out. See `identityserver-usermanagement`.

## Migrating From EF Core

No automated/in-place migration; the schemas differ. Rehearse on a production-like copy.
- **Configuration**: back up EF DB; deploy the Duende schema (separate connection string/schema); export via EF contexts and import through admin APIs (scopes and identity resources first); compare counts; stop config writes, final import, switch to `AddStorage` + `AddConfigurationStorage()`. Use admin APIs, never write records directly (validation, relationships, secret handling, concurrency).
- **Secrets**: EF stores one-way hashes; admin APIs take plaintext. Don't import hashes as plaintext: re-provision from a secure source or rotate. Dynamic IdP secrets are recoverable values: transfer only through a protected process.
- **Operational data** (grants, codes, reference/refresh tokens, sessions, PAR, signing keys, SAML state): no supported transfer tool; lowest-risk is a controlled reset in a maintenance window (users/clients re-authenticate; reference/refresh tokens, device flows, sessions stop working). JWT access tokens remain valid if issuer/audience/signing keys stay continuous: plan signing key rollover separately; don't remove old validation keys until tokens signed with them expire. Don't copy rows directly.
- Keep the EF DB read-only after the final export, verify discovery and each flow before reopening traffic, retain backup + rollback window. Don't dual-write.

## Common Pitfalls

1. ❌ Calling only `AddStorage(...)` and expecting data to be stored → ✅ also call `AddConfigurationStorage()`/`AddOperationalStorage()`.
2. ❌ Believing Duende Storage replaces EF Core / treating EF tables as deprecated → ✅ it is an opt-in alternative.
3. ❌ Registering the same provider twice for one instance (or calling `AddStorage` again for User Management) → `InvalidOperationException`.
4. ❌ Migrating only the default instance → ✅ migrate every named instance via `IStorageInstanceSchemaFactory`.
5. ❌ Importing EF secret hashes into admin APIs → ✅ provision plaintext from a vault or rotate.
6. ❌ Exposing admin services without authn/authz/audit → ✅ protect behind an admin policy, anti-forgery for browsers.
7. ❌ Using `AddDynamicSchemas()` and expecting `AddOidcDynamicProvider()`'s in-memory schema to apply → ✅ create the schema via `ISchemaAdmin`.
8. ❌ Giving the production app DDL permissions by default → ✅ migrate in the deployment pipeline (CLI or script).

## Related Skills

- `identityserver-stores` — EF Core, in-memory, custom stores and caching
- `identityserver-spaces` — multi-tenant isolation built on storage pools
- `identityserver-usermanagement` — shares Duende Storage
- `identityserver-key-management` — signing key store
- `identityserver-deployment` — multi-instance deployment
