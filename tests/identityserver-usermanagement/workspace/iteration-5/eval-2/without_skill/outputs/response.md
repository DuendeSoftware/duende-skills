# Setting Up an SMTP Email Dispatcher for OTP Delivery

To deliver one-time passcodes by email in production, you need a reliable SMTP-backed email sender. The most robust approach in modern .NET is to implement an email service using **MailKit** (the `System.Net.Mail.SmtpClient` type is marked obsolete for new development) and register it so your OTP flow can send codes.

## 1. Package

```bash
dotnet add package MailKit
```

## 2. SMTP Settings in appsettings.json

Keep the transport settings in configuration and the password in a secret store:

```json
"Smtp": {
  "Host": "smtp.example.com",
  "Port": 587,
  "UseStartTls": true,
  "Username": "noreply@example.com",
  "FromAddress": "noreply@example.com",
  "FromName": "My App"
}
```

Store the password with `dotnet user-secrets` locally or an environment variable / key vault in production, e.g. `Smtp__Password`.

## 3. Email Sender Implementation

```csharp
public class SmtpEmailSender : IEmailSender
{
    private readonly SmtpOptions _opt;
    public SmtpEmailSender(IOptions<SmtpOptions> opt) => _opt = opt.Value;

    public async Task SendEmailAsync(string to, string subject, string htmlBody)
    {
        var message = new MimeMessage();
        message.From.Add(new MailboxAddress(_opt.FromName, _opt.FromAddress));
        message.To.Add(MailboxAddress.Parse(to));
        message.Subject = subject;
        message.Body = new TextPart("html") { Text = htmlBody };

        using var client = new SmtpClient();
        await client.ConnectAsync(_opt.Host, _opt.Port, SecureSocketOptions.StartTls);
        await client.AuthenticateAsync(_opt.Username, _opt.Password);
        await client.SendAsync(message);
        await client.DisconnectAsync(true);
    }
}
```

## 4. Register It

```csharp
builder.Services.Configure<SmtpOptions>(builder.Configuration.GetSection("Smtp"));
builder.Services.AddTransient<IEmailSender, SmtpEmailSender>();
```

## 5. Use It to Dispatch the OTP

Wherever you generate the one-time code, call the sender:

```csharp
var code = GenerateOtp();               // your OTP generation
await _emailSender.SendEmailAsync(
    userEmail,
    "Your verification code",
    $"<p>Your code is <strong>{code}</strong>. It expires in 5 minutes.</p>");
```

## Production Tips

- Use port **587 with STARTTLS** (or 465 with implicit TLS) — never send credentials in the clear.
- Consider a transactional email provider (SendGrid, Amazon SES, Postmark) for deliverability, bounce handling, and rate limits.
- Never log the OTP code or the SMTP password.
- Add retry/backoff around the send so a transient SMTP failure doesn't block login.

If the "Duende User Management" component you're using exposes its own dispatcher-registration API, plug this `SmtpEmailSender` into that extension point; the SMTP mechanics above stay the same.
