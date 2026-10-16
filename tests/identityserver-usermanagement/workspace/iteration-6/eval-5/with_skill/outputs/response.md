`AddUserManagement()` is called on the IdentityServer builder and automatically registers `IProfileService`, handles login/logout flows, and maps profile attributes to token claims by requested scope — so you don't write a profile service.

```csharp
using Duende.IdentityServer.Models;
using Duende.UserManagement.Authentication.Otp;

var builder = WebApplication.CreateBuilder(args);

var department = new AttributeDefinition
{
    Code = AttributeCode.Create("department"),
    AttributeType = new ScalarAttributeType(ScalarDataType.String),
    Description = AttributeDescription.Create("The department the user belongs to.")
};

builder.Services.AddIdentityServer(options =>
{
    options.EmitStaticAudienceClaim = true;
    options.UserInteraction.LoginUrl = "/Account/Login";    // where IdentityServer sends users to sign in
    options.UserInteraction.LogoutUrl = "/Account/Logout";  // and to sign out
})
    .AddInMemoryClients(Config.Clients)
    .AddInMemoryIdentityResources(Config.IdentityResources)   // includes OpenId, Profile, Email, plus custom below
    .AddInMemoryApiScopes(Config.ApiScopes)
    .AddStorage(s => s.AddSqlite(o => o.ConnectionString = "Data Source=users.db"))
    .AddUserManagement(options => options.Authentication(a =>
        a.UseSmtpOtpDispatcher(smtp => builder.Configuration.GetSection("Smtp").Bind(smtp))))
    .AddInMemoryDataExtensionSchemas([BuiltInSchemas.UserProfile.Extend(department)]);

builder.Services.AddRazorPages();
var app = builder.Build();

// create schema (MigrateAsync) here — see storage notes

app.UseStaticFiles();
app.UseRouting();
app.UseIdentityServer();    // not UseAuthentication()
app.UseAuthorization();
app.MapRazorPages();
app.MapUserManagement();
app.Run();
```

### Claims in ID tokens
- `openid` → `sub`; `profile` → `name`, `given_name`, `family_name`…; `email` → `email`. The built-in profile schema already has email (unique, required), name, given_name, family_name. `email_verified` is **not** in the built-in schema: add with `BuiltInSchemas.UserProfile.Extend(OidcStandardAttributes.EmailVerified)` and set it (`attributes.Set(AttributeCode.Create("email_verified"), true)`).
- Custom attributes (`department`) are exposed via a **custom identity resource**; add it and allow it on the client:
```csharp
public static IEnumerable<IdentityResource> IdentityResources =>
[
    new IdentityResources.OpenId(), new IdentityResources.Profile(), new IdentityResources.Email(),
    new IdentityResource("department", "Department", ["department"])
];
// Client: AllowedScopes = { "openid","profile","email","department","api1" }
```
The client must request the `department` scope.

`LoginUrl`/`LogoutUrl` must point to your own Razor pages (`/Account/Login`, `/Account/Logout`), otherwise IdentityServer can't redirect users to authenticate.
