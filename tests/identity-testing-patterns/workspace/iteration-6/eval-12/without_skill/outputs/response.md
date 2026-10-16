# HttpClient-only login smoke test

You can drive a server-rendered login (Razor Pages) with `HttpClient` + a `CookieContainer`, replaying what the browser does: authorize → login page → scrape antiforgery token → POST credentials → follow redirects → code.

```csharp
using System.Net;
using System.Text.RegularExpressions;
using Duende.IdentityModel;
using Duende.IdentityModel.Client;

var authority = "https://identity.example.com";
var handler = new HttpClientHandler { AllowAutoRedirect = false, CookieContainer = new CookieContainer(), UseCookies = true };
using var http = new HttpClient(handler);

// 0. discovery
var disco = await http.GetDiscoveryDocumentAsync(authority);
if (disco.IsError) throw new Exception(disco.Error);

// 1. authorize request (code + PKCE)
var verifier = CryptoRandom.CreateUniqueId(32);
var challenge = Base64Url.Encode(System.Security.Cryptography.SHA256.HashData(System.Text.Encoding.ASCII.GetBytes(verifier)));
var authorizeUrl = new RequestUrl(disco.AuthorizeEndpoint!).CreateAuthorizeUrl(
    clientId: "smoke-client", responseType: "code", scope: "openid profile",
    redirectUri: "https://localhost/callback", state: "xyz", codeChallenge: challenge, codeChallengeMethod: "S256");

var r = await http.GetAsync(authorizeUrl);
Assert(r.StatusCode == HttpStatusCode.Redirect, "authorize should redirect to login");

// 2. follow redirect to login page
var loginUrl = new Uri(new Uri(authority), r.Headers.Location!);
var loginHtml = await (await http.GetAsync(loginUrl)).Content.ReadAsStringAsync();
var token = Regex.Match(loginHtml, "name=\"__RequestVerificationToken\"[^>]*value=\"([^\"]+)\"").Groups[1].Value;
var returnUrl = Regex.Match(loginHtml, "name=\"Input.ReturnUrl\"[^>]*value=\"([^\"]*)\"").Groups[1].Value;

// 3. post credentials
var post = await http.PostAsync(loginUrl, new FormUrlEncodedContent(new Dictionary<string, string>
{
    ["Input.Username"] = "smoke-user",
    ["Input.Password"] = Environment.GetEnvironmentVariable("SMOKE_PASSWORD")!,
    ["Input.ReturnUrl"] = System.Net.WebUtility.HtmlDecode(returnUrl),
    ["Input.Button"] = "login",
    ["__RequestVerificationToken"] = token
}));
Assert(post.StatusCode == HttpStatusCode.Redirect, "login should redirect");

// 4. follow redirects manually until callback with code
var next = post.Headers.Location!;
string? code = null;
for (var i = 0; i < 5 && code is null; i++)
{
    var url = next.IsAbsoluteUri ? next : new Uri(new Uri(authority), next);
    if (url.AbsoluteUri.StartsWith("https://localhost/callback"))
    {
        code = System.Web.HttpUtility.ParseQueryString(url.Query)["code"];
        break;
    }
    var resp = await http.GetAsync(url);
    next = resp.Headers.Location ?? throw new Exception("No redirect");
}
Assert(code != null, "should receive authorization code");

// 5. redeem the code
var tokenResponse = await http.RequestAuthorizationCodeTokenAsync(new AuthorizationCodeTokenRequest
{
    Address = disco.TokenEndpoint, ClientId = "smoke-client", ClientSecret = "...",
    Code = code!, RedirectUri = "https://localhost/callback", CodeVerifier = verifier
});
Assert(!tokenResponse.IsError, tokenResponse.Error ?? "");

static void Assert(bool ok, string msg) { if (!ok) throw new Exception("SMOKE FAIL: " + msg); }
```

Tips:
- Use a dedicated test user and client with a loopback/fake redirect URI; the callback is never actually called, you just read the `Location` header.
- Input field names depend on your login page; inspect the form.
- Store credentials in CI secrets; run as a post-deploy pipeline step (exit non-zero on failure).
- Validate the `id_token` too (via `userinfo` endpoint).
- Limitations: doesn't test JavaScript, MFA, or external IdPs — use ROPC-style test hooks or Playwright there.
