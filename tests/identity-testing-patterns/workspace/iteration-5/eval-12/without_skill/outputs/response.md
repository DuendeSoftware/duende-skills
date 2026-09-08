# Login Smoke Test with Only HttpClient (No Headless Browser)

You can smoke-test the login flow against a deployed IdentityServer using a cookie-aware `HttpClient` that fetches the login page, extracts the antiforgery token from the HTML, posts the credentials, and checks that you were redirected back to the app. No Playwright or Selenium required.

I'll parse the HTML with **HtmlAgilityPack** (any HTML parser works):

```
dotnet add package HtmlAgilityPack
```

```csharp
using System.Net;
using HtmlAgilityPack;

[Fact]
public async Task Can_log_in()
{
    // Cookie-aware client so the antiforgery cookie and the auth cookie persist
    var cookies = new CookieContainer();
    using var handler = new HttpClientHandler { CookieContainer = cookies };
    using var client = new HttpClient(handler)
    {
        BaseAddress = new Uri("https://app.example.com")
    };

    // 1) Request a protected page -> redirected to the login page
    var loginPage = await client.GetAsync("/protected");
    var html = await loginPage.Content.ReadAsStringAsync();

    // 2) Parse the HTML and read the antiforgery token
    var doc = new HtmlDocument();
    doc.LoadHtml(html);
    var tokenNode = doc.DocumentNode
        .SelectSingleNode("//input[@name='__RequestVerificationToken']");
    var antiforgery = tokenNode.GetAttributeValue("value", "");

    // 3) Resolve the form action and POST the credentials
    var formNode = doc.DocumentNode.SelectSingleNode("//form");
    var action = new Uri(loginPage.RequestMessage!.RequestUri!,
        formNode.GetAttributeValue("action", "/Account/Login"));

    var result = await client.PostAsync(action, new FormUrlEncodedContent(
        new Dictionary<string, string>
        {
            ["Username"] = "alice",
            ["Password"] = "alice",
            ["__RequestVerificationToken"] = antiforgery
        }));

    // 4) If login succeeded we are redirected back to the application host
    Assert.Equal(new Uri("https://app.example.com").Host,
        result.RequestMessage!.RequestUri!.Host);
}
```

## How it works
1. A `CookieContainer` on the handler keeps the antiforgery cookie (set when the login page renders) and the authentication cookie (issued after a successful POST) so they flow across requests — this is what lets a plain `HttpClient` complete a multi-step login.
2. The login page contains a hidden `__RequestVerificationToken` input; you must read its value and send it back, or the POST is rejected as a CSRF failure.
3. Resolve the form's `action` relative to the login page URL and submit `Username`, `Password`, and the token as `application/x-www-form-urlencoded`.
4. On success the server sets the auth cookie and redirects back to the original protected URL, so the final response's request host equals your app host.

## Notes
- This needs no browser automation — just `HttpClient` and an HTML parser — so it's ideal for a fast post-deployment check.
- The exact form field names depend on your login page. Adjust `Username`/`Password` (and add any submit-button field your template expects) to match your actual login form.
- Consider disabling automatic redirect following only if you want to assert intermediate 302s; here we let redirects flow so we can check the final landing host.
