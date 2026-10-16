---
name: identityserver-usermanagement
description: "Setting up Duende User Management with IdentityServer: passwordless authentication (OTP, TOTP, passkeys), storage configuration, user lifecycle, and migration from ASP.NET Identity."
invocable: false
---

# User Management

## When to Use This Skill

- Adding user management to a Duende IdentityServer project
- Setting up passwordless authentication (OTP, TOTP, passkeys)
- Configuring storage providers (PostgreSQL, SQL Server, SQLite)
- Integrating User Management with IdentityServer for claims and login/logout
- Managing user profiles, roles, and groups
- Migrating users from ASP.NET Identity

## Core Principles

- Duende User Management is **passwordless-first** — OTP email/SMS is the default flow
- Requires `Duende.UserManagement.IdentityServer8` NuGet package + .NET 10
- Storage is **document-based** (no EF migrations) but the schema is **not** auto-created — call `IStorageInstanceSchema.MigrateAsync()` at startup or as a deployment step
- Select the storage provider with `AddStorage(...)` on the IdentityServer builder, not inside `AddUserManagement()`; OTP/authentication options go inside `AddUserManagement(options => options.Authentication(...))`
- Use `app.UseIdentityServer()` (not `UseAuthentication()` separately)

Docs: https://docs.duendesoftware.com/identityserver/usermanagement

## Setup

### 1. Add Packages

```bash
dotnet add package Duende.IdentityServer
dotnet add package Duende.UserManagement.IdentityServer8
dotnet add package Duende.Storage.Sqlite  # or Duende.Storage.PostgreSql, Duende.Storage.MsSql
```

### 2. Configure Program.cs

```csharp
var builder = WebApplication.CreateBuilder(args);

builder.Services.AddIdentityServer(options =>
{
    options.UserInteraction.LoginUrl = "/Account/Login";
    options.UserInteraction.LogoutUrl = "/Account/Logout";
})
    .AddInMemoryClients(Config.Clients)
    .AddInMemoryIdentityResources(Config.IdentityResources)
    // Storage: select a Duende Storage provider on the IdentityServer builder
    .AddStorage(storage => storage.AddSqlite(o => o.ConnectionString = "Data Source=users.db"))
    // .AddStorage(storage => storage.AddPostgreSql())   // needs an NpgsqlDataSource registered in DI
    // .AddStorage(storage => storage.AddMsSql(o => { })) // needs a CreateSqlConnection registered in DI
    .AddUserManagement(options =>
    {
        // OTP delivery
        options.Authentication(auth => auth.UseSmtpOtpDispatcher(smtp =>
            builder.Configuration.GetSection("Smtp").Bind(smtp)));
    });

builder.Services.AddRazorPages();

var app = builder.Build();

// Create/upgrade the database schema (development convenience; use a deployment step in production)
using (var scope = app.Services.CreateScope())
{
    var schemaFactory = scope.ServiceProvider.GetRequiredService<IStorageInstanceSchemaFactory>();
    var schema = await schemaFactory.GetStorageInstanceSchema(CancellationToken.None);
    await schema.MigrateAsync(CancellationToken.None);
}

app.UseIdentityServer();
app.MapRazorPages();
app.Run();
```

### 3. OTP Dispatcher

**Console (development):** User Management ships no console dispatcher; implement `IOtpDispatcher` yourself:
```csharp
using Duende.UserManagement.Authentication.Otp;

public class ConsoleOtpDispatcher : IOtpDispatcher
{
    public bool CanDispatch(OtpAddress address) => true;

    public Task DispatchAsync(OtpAddress address, PlainTextOtp otp, TimeSpan expiresAfter, CancellationToken ct)
    {
        Console.WriteLine($"OTP for {address}: {otp.Text}");
        return Task.CompletedTask;
    }
}

builder.Services.AddSingleton<IOtpDispatcher, ConsoleOtpDispatcher>();
```

**SMTP (production):**
```csharp
.AddUserManagement(options => options.Authentication(auth => auth.UseSmtpOtpDispatcher(x =>
{
    x.Host = "smtp.example.com";       // required
    x.Port = 587;                      // default 1025
    x.EnableSsl = true;                // default true
    x.FromEmail = "noreply@example.com"; // required
    x.FromName = "MyApp";              // required
    x.Domain = "app.example.com";      // optional, used in security warning
    // optional: PlainTextTemplate, HtmlTemplate, SubjectTemplate
})));
```

## Authentication Methods

| Method | Description | Setup |
|--------|-------------|-------|
| **OTP** (default) | One-time codes via email/SMS | `IOtpDispatcher` implementation |
| **TOTP** | Authenticator apps (RFC 6238) | Built-in, user enrollment required |
| **Passkeys** | WebAuthn/FIDO2 phishing-resistant | Built-in, browser support required |
| **Passwords** | Traditional username/password (PBKDF2) | Opt-in, not recommended as primary |
| **External** | OAuth 2.0 / OIDC federated login | Standard ASP.NET Core auth handlers |
| **Recovery codes** | Single-use backup codes | Auto-generated during 2FA setup |

## IdentityServer Integration

`AddUserManagement()` is called on the IdentityServer builder — it automatically:
- Registers `IProfileService` for claims delivery
- Handles login/logout flows
- Maps user attributes to identity token claims

### Claims Mapping

User profile attributes are mapped to claims based on requested scopes:
- `openid` → `sub`
- `profile` → `name`, `given_name`, `family_name`, etc.
- `email` → `email` (`email_verified` is **not** in the built-in profile schema; add it with `BuiltInSchemas.UserProfile.Extend(OidcStandardAttributes.EmailVerified)` and set it, e.g. `attributes.Set(AttributeCode.Create("email_verified"), true)`)

Custom attributes are available through custom identity resources.

## Storage

User Management uses the **Duende Storage** layer (document-based, in a relational DB). Storage is selected with `AddStorage(...)` on the IdentityServer builder, **not** inside `AddUserManagement`. `AddUserManagement(...)` only maps the `user-management` data category to a storage instance.

| Provider | Package | Registration |
|----------|---------|--------------|
| SQLite | `Duende.Storage.Sqlite` | `storage.AddSqlite(o => o.ConnectionString = "...")`; `AddSqliteInMemory()` for tests only |
| PostgreSQL (recommended for production, native JSONB) | `Duende.Storage.PostgreSql` | `storage.AddPostgreSql()` with an `NpgsqlDataSource` singleton in DI; `SchemaName` option |
| SQL Server | `Duende.Storage.MsSql` | `storage.AddMsSql(o => { })` with a `CreateSqlConnection` singleton in DI |

- No EF Core migrations, but the common storage schema must be created: `IStorageInstanceSchema.MigrateAsync` (from `IStorageInstanceSchemaFactory.GetStorageInstanceSchema(ct)`). It's idempotent (advisory locks on PostgreSQL). In production run it as a separate deployment step. `CheckVersionAsync` returns `IsCompatible`/`CurrentVersion`/`RequiredVersion` for a startup compatibility check.
- **Shared instance**: if `AddStorage(...)` already registered a provider for the default instance (with `AddConfigurationStorage()`/`AddOperationalStorage()`), call `AddUserManagement(...)` **without** registering the provider again; IdentityServer and User Management share the DB and schema (different entity types). Selecting a second provider for the same instance throws `InvalidOperationException`.
- **Dedicated database**: `var umInstance = StorageInstanceId.Create("user-management");` + `.AddStorage(umInstance, storage => storage.AddPostgreSql(sp => sp.GetRequiredKeyedService<NpgsqlDataSource>(umInstance.Value)))` + `.AddUserManagement(umInstance, um => { })`. Migrate that instance explicitly: `GetStorageInstanceSchema(umInstance, ct)`.
- This page's storage covers only User Management data (profiles, authenticators, roles, groups); IdentityServer config/operational data uses whichever provider you chose (EF Core, Duende Storage, ...). See `identityserver-duende-storage`.
- With **Spaces**, User Management data is stored in the resolved space's pool by default (isolated users per space); see `identityserver-spaces`.

## Profile Schema

Profile attributes are defined by a schema (`SchemaConfiguration`, `SchemaId.UserProfile`). `AddUserManagement(...)` registers `BuiltInSchemas.UserProfile` (email [unique, required], name, given_name, family_name; each access returns a new mutable instance). With defaults, users register and log in by `email`.

```csharp
// Extend (throws InvalidOperationException if an attribute/group code already exists)
var department = new AttributeDefinition
{
    Code = AttributeCode.Create("department"),
    AttributeType = new ScalarAttributeType(ScalarDataType.String),
    Description = AttributeDescription.Create("The department the user belongs to.")
};
builder.Services.AddIdentityServer()
    .AddUserManagement(_ => { })
    .AddInMemoryDataExtensionSchemas([BuiltInSchemas.UserProfile.Extend(department)]);
```

- `Extend(attributes, groups)` also adds `AttributeGroup`s; attributes get `GroupCode`/`Order` (not unique; apply a secondary sort). There is no dedicated reorder API: build/replace the schema.
- **Replace**: register a full `SchemaConfiguration` with `SchemaId.UserProfile` (e.g. login by a custom `username` attribute); none of the built-in attributes remain unless re-added. A schema with the same `SchemaId` as the built-in always wins; registration order relative to `AddUserManagement` doesn't matter; the last registered wins.
- **Runtime editing**: `AddDynamicSchemas()` gives you `ISchemaAdmin` (get-modify-`UpdateAsync` with the version for optimistic concurrency). In that mode in-memory schemas (including the built-in profile) are **not used or seeded**; `GetAsync(SchemaId.UserProfile)` returns not-found until you create it.
- `OidcStandardAttributes.*` (e.g. `MiddleName`, `Nickname`) can be passed to `Extend`; `Email`/`Name`/`GivenName`/`FamilyName` are already included.
- Removing an attribute from the schema does not purge stored values (validated on write only). `IUserProfileSchemaAdmin` was removed; use `ISchemaAdmin`.
- `profile.ToUpdate()` returns a mutable `AttributeValueCollection` for read-modify-write with `IUserProfileSelfService.TryUpdateAsync(subjectId, update.Validate(), ct)`.
- Membership is managed through the single `IMembershipAdmin` (replaces `IRoleMembershipAdmin`/`IGroupMembershipAdmin`) alongside `IRoleAdmin`/`IGroupAdmin`.

## Passkeys

`AddUserManagement(...)` registers the passkey services automatically (ES/RS/PS signature algorithms, WebAuthn ceremonies, credential storage, challenge management). Passkey endpoints (incl. `/passkeys/js`) require `app.MapUserManagement()`. `ChallengeSize` defaults to 32 bytes (min 16). Stored `Transports` are client-reported hints, not verified. Passkeys can also be a second factor.

## User Lifecycle

- **Creation**: Users are created on first authentication (passwordless) or via admin APIs
- **Profiles**: Custom attributes stored as key-value pairs, organized in attribute groups
- **Roles & Groups**: RBAC support with group membership and role inheritance
- **Deletion**: Full user deletion with cascade

## Migration from ASP.NET Identity

There is no built-in migration option. Read the source ASP.NET Identity database directly (a minimal `IdentityDbContext<IdentityUser>`, not `UserManager`), map each user to a `UserImportRecord`, and call `IUserImporter.ImportAsync` (registered automatically; typically from a hosted service run once on startup, after `MigrateAsync()`).

```csharp
// 1. Register a custom IPasswordHashAlgorithm that verifies the raw ASP.NET Identity hash
builder.Services.AddIdentityServer()
    .AddUserManagement(users => users.Authentication(auth =>
        auth.AddPasswordHashAlgorithm<AspNetIdentityPasswordHashAlgorithm>()));

// 2. Optional: overwrite on re-runs (default resolver skips existing records, retries on concurrency conflicts)
builder.Services.AddSingleton<IUserImportConflictResolver, OverwriteConflictResolver>();
builder.Services.AddHostedService<AspNetIdentityMigrationService>();
```

```csharp
// Hash algorithm (verify-only). Illustrative: Verify is abbreviated; copy the full V2/V3 PBKDF2 implementation from
// https://docs.duendesoftware.com/identityserver/identity/user-management/import/aspnet-identity/
public sealed class AspNetIdentityPasswordHashAlgorithm : IPasswordHashAlgorithm
{
    public const string Id = "aspnet-identity";
    public string AlgorithmId => Id;
    public HashedPasswordData Hash(string password) => throw new NotSupportedException();
    public bool Verify(string password, HashedPasswordData data) =>
        throw new NotImplementedException("See docs: decode base64 blob; 0x00 = V2 PBKDF2-SHA1, 0x01 = V3 (PRF/iterations/salt header)");
    public bool NeedsRehash(HashedPasswordData data) => true; // rehash on first successful login
    public static HashedPasswordData CreateImportData(string aspNetPasswordHash) =>
        new(Id, [], [], new Dictionary<string, string> { ["blob"] = aspNetPasswordHash });
}

// Inside the hosted service's StartAsync (using a scope `sp`)
var sourceDb = sp.GetRequiredService<SourceIdentityDbContext>();   // IdentityDbContext<IdentityUser>
var importer = sp.GetRequiredService<IUserImporter>();
var schema = await sp.GetRequiredService<IUserProfileAdmin>().GetSchemaAsync(ct);
var users = await sourceDb.Users.AsNoTracking().ToListAsync(ct);

var records = users.Select(user =>
{
    var attrs = new AttributeValueCollection(schema);
    // Only set attributes the schema defines, otherwise the import of that record fails
    var emailCode = AttributeCode.Create("email");
    if (!string.IsNullOrEmpty(user.Email) && schema.AttributeDefinitions.ContainsKey(emailCode))
        attrs.Set(emailCode, user.Email);
    var userNameCode = AttributeCode.Create("userName");   // custom/SCIM-style schema only
    if (!string.IsNullOrEmpty(user.UserName) && schema.AttributeDefinitions.ContainsKey(userNameCode))
        attrs.Set(userNameCode, user.UserName);

    return new UserImportRecord
    {
        SubjectId = UserSubjectId.Create(user.Id),       // preserve existing subject ids
        ProfileAttributes = attrs.Validate(),
        Authenticators = new AuthenticatorImport
        {
            Password = string.IsNullOrEmpty(user.PasswordHash) ? null
                : new PasswordImport(AspNetIdentityPasswordHashAlgorithm.CreateImportData(user.PasswordHash))
        }
    };
}).ToList();

const int batchSize = 100;
for (var i = 0; i < records.Count; i += batchSize)
{
    var batch = records.Skip(i).Take(batchSize).ToList();
    UserImportBatchResult result = await importer.ImportAsync(batch, ct);
    foreach (var r in result.Results.Where(r => r.Status == UserImportStatus.Failed))
        logger.LogWarning("FAILED {SubjectId}: {Error}", r.SubjectId, r.Error);
}
```

Key points:
- Each record is imported independently; one failure doesn't affect others. Import is idempotent for new users (existing records are skipped by default); register an `IUserImportConflictResolver` to overwrite.
- Passwords: store the original hash as-is via `PasswordImport(HashedPasswordData)`; the custom `IPasswordHashAlgorithm` verifies it and User Management re-hashes with its preferred algorithm on the first successful login.
- Claims from `AspNetUserClaims` map to profile attributes; `name`, `emails`, `phoneNumbers`, `addresses` are complex attributes (dictionaries), and attributes missing from the schema cause import failure, so guard with `schema.AttributeDefinitions.ContainsKey(...)`.
- `AuthenticatorImport` also supports `OtpAddresses`, `Passkeys`, `TotpAuthenticators`, `ExternalAuthenticatorAddresses`, `RecoveryCodes`; `MembershipImport` (groups/roles must already exist).
- After migration, users can enroll in passwordless methods. Test with a small batch first.
- Full guide: user-management/import/aspnet-identity and import/reference docs.

## Common Anti-Patterns

❌ Putting storage config inside `AddUserManagement()` — select the provider with `.AddStorage(...)` on the IdentityServer builder
❌ Using `UseAuthentication()` instead of `UseIdentityServer()` — IdentityServer middleware handles auth
❌ Skipping `IStorageInstanceSchema.MigrateAsync()` — database tables won't exist on first run
❌ Calling `AddStorage(...)` again for the same instance when IdentityServer already registered it — throws
❌ Using in-memory storage in production — data is lost on restart

## Common Pitfalls

1. **Storage configuration location**: storage is selected with `AddStorage(storage => storage.AddSqlite(...))` on the IdentityServer builder; `AddUserManagement(...)` maps its data to the (default or a named) storage instance.
2. **.NET 10 required**: User Management requires .NET 10 SDK or later.
3. **OTP dispatcher required**: Without an `IOtpDispatcher`, the default OTP flow cannot send codes. Implement and register your own `IOtpDispatcher` (e.g. a console one) for development.
4. **LoginUrl/LogoutUrl**: Must be set in IdentityServer options to point to your account pages.
5. **Schema creation**: Run `IStorageInstanceSchema.MigrateAsync()` (per instance) before the app handles requests; in production prefer a deployment step.

## Related Skills

- `identityserver-duende-storage` — Duende Storage provider, instances and schemas
- `identityserver-spaces` — per-space user isolation
- `identityserver-configuration` — IdentityServer host configuration and options
- `identityserver-ui-flows` — Login/logout UI flows
- `identityserver-upgrade-v7-to-v8` — Migration guide for v8 (includes User Management as new feature)
- `aspnetcore-authentication` — ASP.NET Core authentication fundamentals
