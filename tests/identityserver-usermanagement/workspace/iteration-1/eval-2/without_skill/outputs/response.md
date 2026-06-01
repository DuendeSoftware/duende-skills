# Configuring Email OTP for Production

For sending OTP emails in production with IdentityServer, you'll typically implement a custom email sender. Here's a general approach:

## Using IEmailSender with SMTP

```csharp
public class SmtpEmailSender : IEmailSender
{
    private readonly SmtpSettings _settings;

    public SmtpEmailSender(IOptions<SmtpSettings> settings)
    {
        _settings = settings.Value;
    }

    public async Task SendEmailAsync(string email, string subject, string htmlMessage)
    {
        using var client = new SmtpClient(_settings.Host, _settings.Port);
        client.Credentials = new NetworkCredential(_settings.Username, _settings.Password);
        client.EnableSsl = true;

        var message = new MailMessage(
            from: _settings.FromAddress,
            to: email,
            subject: subject,
            body: htmlMessage);
        message.IsBodyHtml = true;

        await client.SendMailAsync(message);
    }
}

public class SmtpSettings
{
    public string Host { get; set; }
    public int Port { get; set; }
    public string Username { get; set; }
    public string Password { get; set; }
    public string FromAddress { get; set; }
}
```

## Registration in Program.cs

```csharp
builder.Services.Configure<SmtpSettings>(
    builder.Configuration.GetSection("Smtp"));
builder.Services.AddTransient<IEmailSender, SmtpEmailSender>();
```

## appsettings.json

```json
{
  "Smtp": {
    "Host": "smtp.example.com",
    "Port": 587,
    "Username": "noreply@example.com",
    "Password": "your-password",
    "FromAddress": "noreply@example.com"
  }
}
```

## Notes

- Use `MailKit` for more robust SMTP handling in production.
- Store credentials in user secrets or a vault, not in appsettings.
- For the OTP flow itself, you'd use ASP.NET Identity's token providers to generate and validate codes.
