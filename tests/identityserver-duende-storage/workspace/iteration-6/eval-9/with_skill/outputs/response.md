Duende Storage (preview) separates schema deployment from runtime. **Don't give the app DDL rights**: run migrations as a pipeline step.

## PostgreSQL: Duende CLI
```bash
dotnet tool install --global Duende.Cli --prerelease

export DUENDE_STORAGE_CONNECTION_STRING="$MIGRATION_CONN"   # DDL-capable account from the secret store
duende storage migrate --provider postgresql --dry-run      # review
duende storage migrate --provider postgresql                # apply
# non-default schema: add --schema my_schema
```
The CLI downloads and caches `Duende.Storage.CliPlugin` from NuGet on first use, so the build agent needs NuGet access. Supported providers are `mssql`, `postgresql` and `sqlite`.

## Oracle: DBA-applied script
**The CLI doesn't support Oracle.** Generate the SQL with `IStorageInstanceSchema.BuildMigrationScript` and have a DBA (or a gated pipeline job with a DDL account) apply it:
```csharp
var script = await app.Services.GetRequiredService<IStorageInstanceSchema>().BuildMigrationScript(ct);
await File.WriteAllTextAsync("duende-storage-oracle.sql", script, ct);
```
Run this from a small build/tooling step (not at normal app startup) and publish the file as a reviewed pipeline artifact.

## Rules
- **Don't call `MigrateAsync` at startup in production**. It needs DDL. It's fine only in Development. After migrating, it verifies the DB matches the expected schema, so keep app and schema versions aligned.
- Run **one migration process at a time** (serialize the job and prevent parallel deploys).
- **Every storage instance** needs migrating, and the CLI handles one connection string at a time, so run it per instance (default, operational, and so on). For named instances in code, use `IStorageInstanceSchemaFactory.GetStorageInstanceSchema(id, ct)`.
- Don't hide a missing connection string, and **fail the pipeline** if migration fails. Don't continue deployment.
- The app runtime uses a separate, narrower DB identity (DML only). Keep credentials in a secret store.
- Order: migrate (dry run, approval, apply), then deploy the app.
