**Two problems — both are in the skill's anti-patterns list.**

1. **`AddSqliteStore` doesn't belong inside `AddUserManagement`.** Storage is selected on the IdentityServer builder with `AddStorage(...)`. `AddUserManagement(...)` only configures authentication/OTP options and maps its data to a storage instance. (The method is `storage.AddSqlite(...)`.)
2. **The database is never created because the schema isn't auto-created.** Storage is document-based (no EF migrations) but you must call `IStorageInstanceSchema.MigrateAsync()`.

```csharp
builder.Services.AddIdentityServer(options =>
{
    options.EmitStaticAudienceClaim = true;
    options.UserInteraction.LoginUrl = "/Account/Login";
    options.UserInteraction.LogoutUrl = "/Account/Logout";
})
    .AddInMemoryClients(Config.Clients)
    .AddInMemoryIdentityResources(Config.IdentityResources)
    .AddInMemoryApiScopes(Config.ApiScopes)
    .AddStorage(storage => storage.AddSqlite(o => o.ConnectionString = "Data Source=users.db"))
    .AddUserManagement(options => { /* OTP / authentication options only */ });

var app = builder.Build();

using (var scope = app.Services.CreateScope())
{
    var factory = scope.ServiceProvider.GetRequiredService<IStorageInstanceSchemaFactory>();
    var schema = await factory.GetStorageInstanceSchema(CancellationToken.None);
    await schema.MigrateAsync(CancellationToken.None);   // idempotent
}

app.UseStaticFiles();
app.UseRouting();
app.UseIdentityServer();   // not UseAuthentication()
app.UseAuthorization();
app.MapRazorPages();
app.Run();
```
Package needed: `Duende.Storage.Sqlite`. Also: you need .NET 10 and an `IOtpDispatcher` registered (or SMTP dispatcher) so OTP codes can be sent. In production, run `MigrateAsync` as a deployment step.
