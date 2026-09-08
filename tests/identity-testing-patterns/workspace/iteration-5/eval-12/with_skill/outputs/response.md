# Post-Deployment Login Smoke Test with HttpClient + AngleSharp (No Browser)

You can verify the interactive login flow against a deployed IdentityServer without Playwright/Selenium by driving a **cookie-aware `HttpClient`** and parsing the login HTML with **AngleSharp**. The client follows the authorize → login-form → post-back → redirect-back chain, and you assert you ended back on the protected host.

```
dotnet add package AngleSharp
```

```csharp
using System.Net;
using AngleSharp.Html.Parser;

[Fact]
public async Task User_can_log_in_via_the_login_form()
{
    // ✅ Cookie-aware client so the antiforgery + auth/session cookies flow across requests
    var cookies = new CookieContainer();
    using var handler = new HttpClientHandler { CookieContainer = cookies };
    using var client = new HttpClient(handler)
    {
        BaseAddress = new Uri("https://app.example.com")
    };

    // 1) GET the protected URL — auto-redirects to the IdentityServer login page
    var loginPage = await client.GetAsync("/protected");

    // 2) Parse the login HTML and read the antiforgery token from the form
    var html = await loginPage.Content.ReadAsStringAsync();
    var doc = await new HtmlParser().ParseDocumentAsync(html);
    var form = doc.QuerySelector("form")!;
    var antiforgery = form
        .QuerySelector("input[name='__RequestVerificationToken']")!
        .GetAttribute("value");

    // 3) POST credentials to the form's resolved action URL
    var action = new Uri(loginPage.RequestMessage!.RequestUri!, form.GetAttribute("action"));
    var result = await client.PostAsync(action, new FormUrlEncodedContent(
        new Dictionary<string, string>
        {
            ["Username"] = "alice",
            ["Password"] = "alice",
            ["__RequestVerificationToken"] = antiforgery!,
            ["button"] = "login"
        }));

    // 4) Success = we ended back on the original protected host
    Assert.Equal(new Uri("https://app.example.com").Host,
        result.RequestMessage!.RequestUri!.Host);
}
```

## How each step maps to the flow
1. **Cookie-aware client.** A `CookieContainer` on the `HttpClientHandler` stores the antiforgery cookie set on the login page and the auth/session cookie issued after login, and replays them on subsequent requests — this is what makes the multi-request flow work without a browser.
2. **AngleSharp HTML parse.** `new HtmlParser().ParseDocumentAsync(html)` turns the login page into a queryable DOM so you can locate the form and its hidden fields.
3. **Read the antiforgery token.** `input[name='__RequestVerificationToken']` → `GetAttribute("value")` extracts the token the server expects back on POST.
4. **POST to the resolved action.** Resolve the form's `action` against the login page's actual URL, then submit `FormUrlEncodedContent` with `Username`, `Password`, the `__RequestVerificationToken`, and `button=login` (the default Duende login form's field names).
5. **Assert on the final host.** After a successful login the flow redirects back to the app; comparing `result.RequestMessage!.RequestUri!.Host` to the original protected host confirms you landed home rather than staying on the IdP's login page.

## Caveats
- This uses **no headless browser** — just `HttpClient` and AngleSharp — so it runs anywhere and is cheap for CI/post-deploy checks.
- The field names assume the **default template login form**. If you customized the login UI, adjust the selectors and posted field names.
- It's a smoke test: it confirms the deployed flow *works*, not per-claim correctness — use the in-process patterns for detailed claim assertions.
