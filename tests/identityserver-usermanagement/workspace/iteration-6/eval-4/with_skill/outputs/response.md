There is no built-in "migrate" switch, but there is a supported import path that preserves subject IDs and passwords, so users keep access.

**Approach:** read the legacy ASP.NET Identity database directly (a minimal `IdentityDbContext<IdentityUser>`, not `UserManager`), map each user to a `UserImportRecord`, and call `IUserImporter.ImportAsync` (registered automatically), typically from a hosted service run once at startup after `MigrateAsync()`.

### 1. Register a verify-only password hash algorithm
```csharp
builder.Services.AddIdentityServer()
    .AddUserManagement(users => users.Authentication(auth =>
        auth.AddPasswordHashAlgorithm<AspNetIdentityPasswordHashAlgorithm>()));

// optional: overwrite existing records on re-runs (default skips existing)
builder.Services.AddSingleton<IUserImportConflictResolver, OverwriteConflictResolver>();
builder.Services.AddHostedService<AspNetIdentityMigrationService>();
```
```csharp
public sealed class AspNetIdentityPasswordHashAlgorithm : IPasswordHashAlgorithm
{
    public const string Id = "aspnet-identity";
    public string AlgorithmId => Id;
    public HashedPasswordData Hash(string password) => throw new NotSupportedException();
    public bool Verify(string password, HashedPasswordData data) =>
        throw new NotImplementedException("Copy the full V2/V3 PBKDF2 verification from the Duende docs: 0x00 = V2 PBKDF2-SHA1, 0x01 = V3 header with PRF/iterations/salt");
    public bool NeedsRehash(HashedPasswordData data) => true; // rehash on first successful login
    public static HashedPasswordData CreateImportData(string hash) =>
        new(Id, [], [], new Dictionary<string, string> { ["blob"] = hash });
}
```
(`Verify` is abbreviated here; use the reference implementation from the docs' ASP.NET Identity import page.)

### 2. Import service
```csharp
var sourceDb = sp.GetRequiredService<SourceIdentityDbContext>();
var importer = sp.GetRequiredService<IUserImporter>();
var schema = await sp.GetRequiredService<IUserProfileAdmin>().GetSchemaAsync(ct);
var users = await sourceDb.Users.AsNoTracking().ToListAsync(ct);

var records = users.Select(user =>
{
    var attrs = new AttributeValueCollection(schema);
    var emailCode = AttributeCode.Create("email");
    if (!string.IsNullOrEmpty(user.Email) && schema.AttributeDefinitions.ContainsKey(emailCode))
        attrs.Set(emailCode, user.Email);

    return new UserImportRecord
    {
        SubjectId = UserSubjectId.Create(user.Id),   // preserve existing subject ids
        ProfileAttributes = attrs.Validate(),
        Authenticators = new AuthenticatorImport
        {
            Password = string.IsNullOrEmpty(user.PasswordHash) ? null
                : new PasswordImport(AspNetIdentityPasswordHashAlgorithm.CreateImportData(user.PasswordHash))
        }
    };
}).ToList();

for (var i = 0; i < records.Count; i += 100)
{
    UserImportBatchResult result = await importer.ImportAsync(records.Skip(i).Take(100).ToList(), ct);
    foreach (var r in result.Results.Where(r => r.Status == UserImportStatus.Failed))
        logger.LogWarning("FAILED {SubjectId}: {Error}", r.SubjectId, r.Error);
}
```

### Why users don't lose access
- `SubjectId` is preserved, so existing grants and downstream data still match.
- The original hash is stored as-is; the custom algorithm verifies it and User Management re-hashes with its preferred algorithm on first successful login.
- Each record imports independently; one failure doesn't affect others; existing records are skipped by default (idempotent).
- Attributes not in the schema make that record fail, so guard with `schema.AttributeDefinitions.ContainsKey(...)` or extend the schema first. `AspNetUserClaims` map to profile attributes.
- `AuthenticatorImport` also supports `OtpAddresses`, `Passkeys`, `TotpAuthenticators`, `ExternalAuthenticatorAddresses`, `RecoveryCodes`; `MembershipImport` for groups/roles (which must already exist).
- Test with a small batch first. Afterwards users can enroll in passwordless methods.
