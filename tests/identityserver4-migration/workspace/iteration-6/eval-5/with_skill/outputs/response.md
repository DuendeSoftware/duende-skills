## IdentityServer4 v3 → v4: scopes become top-level

In v3 `ApiScope` (`Scope`) was a child of `ApiResource`. In v4 scopes are independent with a many-to-many relationship to API resources; `ApiResource.Scopes` is a list of **scope name strings**.

```csharp
// v3
new ApiResource("api1", "My API")
{
    Scopes = { new Scope("api1.read"), new Scope("api1.write") }
}

// v4
public static IEnumerable<ApiScope> ApiScopes => new[]
{
    new ApiScope("api1.read", "Read access to API 1"),
    new ApiScope("api1.write", "Write access to API 1")
};

public static IEnumerable<ApiResource> ApiResources => new[]
{
    new ApiResource("api1", "My API")
    {
        Scopes = { "api1.read", "api1.write" }
    }
};

services.AddIdentityServer()
    .AddInMemoryApiScopes(Config.ApiScopes)      // new in v4
    .AddInMemoryApiResources(Config.ApiResources)
    .AddInMemoryClients(Config.Clients);
```
(Your current Config.cs already has this v4 shape.) The `Scope` type no longer exists in v4 — errors about it mean `ApiResource.Scopes` still uses objects.

Other v3→v4 code changes: `SignInAsync(subjectId, name, props)` → `new IdentityServerUser(id){DisplayName=...}`; `request.ClientId` → `request.Client.ClientId`; `ScopesRequested` → `ValidatedResources.RawScopeValues`; `ScopesConsented` → `ScopesValuesConsented`; `GetAllUserConsentsAsync` → `GetAllUserGrantsAsync`; `IsPkceClientAsync` → `context.IsNativeClient()`; `ProcessLoginCallbackForOidc/WsFed/Saml2p` → `ProcessLoginCallback`.

## Database migration

Update packages to IdentityServer4 4.1.2 first.

**PersistedGrantDbContext** — standard:
```bash
dotnet ef migrations add Grants_v4 -c PersistedGrantDbContext -o Migrations/PersistedGrantDb
dotnet ef database update -c PersistedGrantDbContext
```
(adds `ConsumedTime`, `Description`, `SessionId`.)

**ConfigurationDbContext** — needs custom SQL. The auto-generated migration will **drop and recreate tables and lose data**. Tables are renamed: `ApiClaims`→`ApiResourceClaims`, `ApiProperties`→`ApiResourceProperties`, `ApiSecrets`→`ApiResourceSecrets`, `IdentityClaims`→`IdentityResourceClaims`, `IdentityProperties`→`IdentityResourceProperties`, and scopes link via `ApiResourceScopes`.

```bash
dotnet ef migrations add Config_v4 -c ConfigurationDbContext -o Migrations/ConfigurationDb
```
Then edit the migration to run a delta SQL script before the destructive operations:
```sql
INSERT INTO ApiResourceClaims (Id, [Type], ApiResourceId) SELECT Id, [Type], ApiResourceId FROM ApiClaims;
INSERT INTO ApiResourceProperties (Id, [Key], [Value], ApiResourceId) SELECT Id, [Key], [Value], ApiResourceId FROM ApiProperties;
INSERT INTO ApiResourceSecrets (Id, [Description], [Value], [Expiration], [Type], [Created], ApiResourceId)
  SELECT Id, [Description], [Value], [Expiration], [Type], [Created], ApiResourceId FROM ApiSecrets;
INSERT INTO IdentityResourceClaims (Id, [Type], IdentityResourceId) SELECT Id, [Type], IdentityResourceId FROM IdentityClaims;
INSERT INTO IdentityResourceProperties (Id, [Key], [Value], IdentityResourceId) SELECT Id, [Key], [Value], IdentityResourceId FROM IdentityProperties;
INSERT INTO ApiResourceScopes ([Scope], [ApiResourceId]) SELECT [Name], [ApiResourceId] FROM ApiScopes;
```
Then `dotnet ef database update -c ConfigurationDbContext`. Reference: the `UpgradeSample-IdentityServer4-v3` repo from Duende. Back up first. Only after this go on to the Duende migration.
