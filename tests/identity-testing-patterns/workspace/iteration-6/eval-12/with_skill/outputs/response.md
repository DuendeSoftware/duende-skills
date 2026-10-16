# Post-deployment login smoke test with just HttpClient

Drive the real login flow with a **cookie-aware `HttpClient`** and parse the login HTML with **AngleSharp** to extract the antiforgery token. No Playwright/Selenium needed. It exercises authorize → login form → post back → redirect back.

```
dotnet add package AngleSharp
```

```csharp
using System.Net;
using AngleSharp.Html.Parser;

public class LoginSmokeTests
{
    [Fact]
    public async Task User_can_log_in_via_the_login_form()
    {
        // ✅ Cookie container so antiforgery + auth cookies flow across requests
        var cookies = new CookieContainer();
        using var handler = new HttpClientHandler { CookieContainer = cookies };
        using var client = new HttpClient(handler) { BaseAddress = new Uri("https://app.example.com") };

        // 1) GET a protected URL — auto-redirects to the IdentityServer login page
        var loginPage = await client.GetAsync("/protected");

        // 2) Parse the HTML and read the antiforgery token from the form
        var html = await loginPage.Content.ReadAsStringAsync();
        var doc = await new HtmlParser().ParseDocumentAsync(html);
        var form = doc.QuerySelector("form")!;
        var antiforgery = form.QuerySelector("input[name='__RequestVerificationToken']")!
            .GetAttribute("value");

        // 3) POST credentials to the form's resolved action URL
        var action = new Uri(loginPage.RequestMessage!.RequestUri!, form.GetAttribute("action"));
        var result = await client.PostAsync(action, new FormUrlEncodedContent(new Dictionary<string, string>
        {
            ["Username"] = Environment.GetEnvironmentVariable("SMOKE_USER")!,
            ["Password"] = Environment.GetEnvironmentVariable("SMOKE_PASSWORD")!,
            ["__RequestVerificationToken"] = antiforgery!,
            ["button"] = "login"
        }));

        // 4) Success = we ended up back on the original app host (login redirected us home)
        Assert.Equal(new Uri("https://app.example.com").Host,
            result.RequestMessage!.RequestUri!.Host);
    }
}
```

## How it works
- `HttpClientHandler` follows redirects by default, so the chain app → IdentityServer login → back to app happens automatically. `RequestMessage.RequestUri` of the final response tells you where you landed.
- The antiforgery cookie set on the GET and the `__RequestVerificationToken` form field must match, hence the shared `CookieContainer`.
- Resolve the form `action` against the page's URL (it's often relative or carries the `ReturnUrl`).

## Caveats
- Field names (`Username`, `Password`, `__RequestVerificationToken`, `button=login`) match the **default template login form**; adjust selectors if you customized the UI.
- It's a smoke test: it confirms the deployed flow works, not per-claim correctness. Use in-process `WebApplicationFactory` tests for that.
- Use a dedicated test account; keep credentials in CI secrets (environment variables), and run it as a post-deploy pipeline step (non-zero exit on failure).
- It can't cover JavaScript-driven UI, MFA, or external IdP redirects.
