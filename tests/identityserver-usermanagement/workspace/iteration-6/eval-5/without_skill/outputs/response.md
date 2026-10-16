I'm not sure of Duende User Management's exact API; verify names with the docs.

```csharp
builder.Services.AddUserManagement(/* options */).AddSqliteStore("Data Source=um.db");

builder.Services.AddIdentityServer(options =>
{
    options.EmitStaticAudienceClaim = true;
    options.UserInteraction.LoginUrl = "/Account/Login";
    options.UserInteraction.LogoutUrl = "/Account/Logout";
})
.AddInMemoryClients(Config.Clients)
.AddInMemoryIdentityResources(Config.IdentityResources)
.AddInMemoryApiScopes(Config.ApiScopes)
.AddProfileService<UserManagementProfileService>();
```
Profile service (maps user attributes to claims):
```csharp
public class UserManagementProfileService(/* user store */) : IProfileService
{
    public async Task GetProfileDataAsync(ProfileDataRequestContext ctx)
    {
        var user = await store.FindByIdAsync(ctx.Subject.GetSubjectId());
        var claims = new List<Claim> { new("email", user.Email), new("department", user.Attributes["department"]) };
        ctx.AddRequestedClaims(claims);
    }
    public Task IsActiveAsync(IsActiveContext ctx) { ctx.IsActive = true; return Task.CompletedTask; }
}
```
For custom claims to appear in ID tokens, define an IdentityResource containing them (`new IdentityResource("custom", new[]{"department"})`), add it to the client's `AllowedScopes`, and have the client request that scope (or set `AlwaysIncludeUserClaimsInIdToken`). Login page signs in with `HttpContext.SignInAsync` after validating, and logout page calls `SignOutAsync` and redirects to the `PostLogoutRedirectUri`.
