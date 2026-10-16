I'm not sure of the exact Duende User Management API, so verify names against the docs. The general approach: implement an email-dispatch abstraction that sends the OTP via SMTP and register it.

```csharp
public class SmtpOtpDispatcher(IOptions<SmtpOptions> opt) : IOtpDispatcher // interface name approximate
{
    public async Task SendAsync(string email, string code, CancellationToken ct)
    {
        var o = opt.Value;
        using var client = new SmtpClient(o.Host, o.Port) { EnableSsl = true,
            Credentials = new NetworkCredential(o.User, o.Password) };
        await client.SendMailAsync(new MailMessage(o.From, email, "Your sign-in code",
            $"Your code is {code}. It expires in 10 minutes."), ct);
    }
}

builder.Services.Configure<SmtpOptions>(builder.Configuration.GetSection("Smtp"));
builder.Services.AddSingleton<IOtpDispatcher, SmtpOtpDispatcher>();
```
Production tips: keep SMTP credentials in a secret store/env vars, use TLS, prefer MailKit over the obsolete SmtpClient, rate limit OTP requests, and don't log codes.
