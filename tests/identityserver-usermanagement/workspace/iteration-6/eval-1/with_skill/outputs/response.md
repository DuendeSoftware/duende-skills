## Packages
```bash
dotnet add package Duende.UserManagement.IdentityServer8
dotnet add package Duende.Storage.Sqlite
```
(`Duende.IdentityServer` 8.0.0 and .NET 10 are already in place; User Management requires both.)

## appsettings.json
```json
{
  "Smtp": { "Host": "localhost", "Port": 1025, "EnableSsl": false,
            "FromEmail": "noreply@example.com", "FromName": "MyApp" }
}
```

## Program.cs
```csharp
using Duende.IdentityServer.Models;
using Duende.UserManagement.Authentication.Otp;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddIdentityServer(options =>
{
    options.EmitStaticAudienceClaim = true;
    options.UserInteraction.LoginUrl = "/Account/Login";
    options.UserInteraction.LogoutUrl = "/Account/Logout";
})
    .AddInMemoryClients(Config.Clients)
    .AddInMemoryIdentityResources(Config.IdentityResources)
    .AddInMemoryApiScopes(Config.ApiScopes)
    // Storage is selected on the IdentityServer builder, NOT inside AddUserManagement
    .AddStorage(storage => storage.AddSqlite(o => o.ConnectionString = "Data Source=users.db"))
    .AddUserManagement(); // OTP is the default flow

// No console dispatcher ships with User Management: implement IOtpDispatcher for dev
builder.Services.AddSingleton<IOtpDispatcher, ConsoleOtpDispatcher>();

builder.Services.AddRazorPages();

var app = builder.Build();

// The schema is NOT auto-created (no EF migrations; document-based storage)
using (var scope = app.Services.CreateScope())
{
    var factory = scope.ServiceProvider.GetRequiredService<IStorageInstanceSchemaFactory>();
    var schema = await factory.GetStorageInstanceSchema(CancellationToken.None);
    await schema.MigrateAsync(CancellationToken.None);
}

app.UseStaticFiles();
app.UseRouting();
app.UseIdentityServer();   // handles authentication; no separate UseAuthentication()
app.UseAuthorization();
app.MapRazorPages();
app.MapUserManagement();   // needed for e.g. passkey endpoints
app.Run();

public class ConsoleOtpDispatcher : IOtpDispatcher
{
    public bool CanDispatch(OtpAddress address) => true;
    public Task DispatchAsync(OtpAddress address, PlainTextOtp otp, TimeSpan expiresAfter, CancellationToken ct)
    {
        Console.WriteLine($"OTP for {address}: {otp.Text}");
        return Task.CompletedTask;
    }
}
// Config class unchanged
```

For email delivery instead of console, use `.AddUserManagement(o => o.Authentication(a => a.UseSmtpOtpDispatcher(s => builder.Configuration.GetSection("Smtp").Bind(s))))`.

## Notes
- Users are created on first successful authentication; with the default profile schema they log in by `email`.
- `AddUserManagement` registers `IProfileService`, so `email`/`profile` claims flow to tokens automatically.
- `MigrateAsync` is idempotent; in production run it as a deployment step.
- Don't put `AddSqlite` inside `AddUserManagement`.
