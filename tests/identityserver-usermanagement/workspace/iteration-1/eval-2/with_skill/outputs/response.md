# Configuring SMTP OTP Dispatcher for Production

To configure email OTP delivery in production with Duende User Management, use `UseSmtpOtpDispatcher()` inside the `AddUserManagement()` options lambda:

```csharp
builder.Services.AddIdentityServer(options =>
{
    options.UserInteraction.LoginUrl = "/Account/Login";
    options.UserInteraction.LogoutUrl = "/Account/Logout";
})
    .AddInMemoryClients(Config.Clients)
    .AddInMemoryIdentityResources(Config.IdentityResources)
    .AddUserManagement(options =>
    {
        options.AddSqliteStore("Data Source=users.db");

        // Production SMTP configuration
        options.UseSmtpOtpDispatcher(smtp =>
        {
            smtp.Host = "smtp.example.com";
            smtp.Port = 587;
            smtp.Username = "noreply@example.com";
            smtp.Password = "your-smtp-password";
            smtp.FromAddress = "noreply@example.com";
        });
    });
```

## Important Notes

- **Do NOT use `ConsoleOtpDispatcher` in production** — it only writes OTP codes to the console output and is intended for development/testing only.
- `UseSmtpOtpDispatcher()` must be called **inside** the `AddUserManagement()` options lambda.
- For sensitive credentials, use configuration binding instead of hardcoding:

```csharp
options.UseSmtpOtpDispatcher(smtp =>
    builder.Configuration.GetSection("Smtp").Bind(smtp));
```

With `appsettings.json`:

```json
{
  "Smtp": {
    "Host": "smtp.example.com",
    "Port": 587,
    "Username": "noreply@example.com",
    "Password": "your-smtp-password",
    "FromAddress": "noreply@example.com"
  }
}
```

The SMTP dispatcher sends one-time codes to the user's registered email address as part of the default passwordless OTP authentication flow.
