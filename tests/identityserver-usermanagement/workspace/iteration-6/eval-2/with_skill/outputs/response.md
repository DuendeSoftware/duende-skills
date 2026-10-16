Use the built-in SMTP dispatcher inside `AddUserManagement`'s `Authentication` options (storage stays on `AddStorage`).

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
    .AddStorage(s => s.AddPostgreSql())   // needs an NpgsqlDataSource in DI
    .AddUserManagement(options => options.Authentication(auth => auth.UseSmtpOtpDispatcher(x =>
    {
        x.Host = "smtp.example.com";          // required
        x.Port = 587;                         // default is 1025
        x.EnableSsl = true;                   // default true
        x.FromEmail = "noreply@example.com";  // required
        x.FromName = "MyApp";                 // required
        x.Domain = "app.example.com";         // optional, used in the security warning
        // optional: PlainTextTemplate, HtmlTemplate, SubjectTemplate
    })));
```

Bind from configuration rather than hard-coding, and keep credentials out of source:
```csharp
auth.UseSmtpOtpDispatcher(smtp => builder.Configuration.GetSection("Smtp").Bind(smtp))
```
```json
"Smtp": { "Host": "smtp.example.com", "Port": 587, "EnableSsl": true,
          "FromEmail": "noreply@example.com", "FromName": "MyApp" }
```

Remember: the default port is 1025 (a dev-style port), so set 587/465 explicitly for production; `Host`, `FromEmail`, `FromName` are required. Without any `IOtpDispatcher`, OTP codes can't be sent. Also call `app.UseIdentityServer()` and run `MigrateAsync()` for the storage schema.
