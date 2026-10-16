# Adding Dynamic Client Registration (DCR)

DCR (RFC 7591) is served at `/connect/dcr` by the separate **Duende.IdentityServer.Configuration** package. It requires a **Business Edition or higher** license (Community Edition doesn't support it).

## 1. NuGet package
```bash
dotnet add package Duende.IdentityServer.Configuration
```
(Your csproj gets `<PackageReference Include="Duende.IdentityServer.Configuration" Version="8.0.0" />` alongside the existing IdentityServer reference.)

## 2. Service registration + endpoint mapping + security
```csharp
using Duende.IdentityServer.Configuration;

// existing AddIdentityServer()... stays as is

builder.Services.AddIdentityServerConfiguration();   // registers DCR services

// Secure the endpoint: JWT bearer + scope
builder.Services.AddAuthentication()
    .AddJwtBearer("dcr", options =>
    {
        options.Authority = "https://identity.example.com";
        options.Audience = "IdentityServer.Configuration";
        options.TokenValidationParameters.ValidTypes = ["at+jwt"];
    });

builder.Services.AddAuthorization(options =>
{
    options.AddPolicy("dcr", policy =>
    {
        policy.AddAuthenticationSchemes("dcr");
        policy.RequireAuthenticatedUser();
        policy.RequireClaim("scope", "IdentityServer.Configuration");
    });
});

builder.Services.AddRazorPages();
var app = builder.Build();

app.UseStaticFiles();
app.UseRouting();
app.UseIdentityServer();
app.UseAuthorization();

app.MapRazorPages();
app.MapDynamicClientRegistration().RequireAuthorization("dcr");   // maps /connect/dcr

app.Run();
```
Both calls are required: `AddIdentityServerConfiguration()` registers the services, `MapDynamicClientRegistration()` maps the endpoint. Never leave it unauthenticated.

Your existing `dcr.manager` client (client credentials, scope `IdentityServer.Configuration`) is what obtains the token. Because the `at+jwt` token must carry the `IdentityServer.Configuration` audience, define an `ApiResource` containing that scope (or adjust the `Audience`).

## 3. Try it
```http
POST /connect/dcr HTTP/1.1
Content-Type: application/json
Authorization: Bearer <access_token>

{
  "client_name": "My Dynamic App",
  "redirect_uris": ["https://app.example.com/callback"],
  "grant_types": ["authorization_code"],
  "response_types": ["code"],
  "token_endpoint_auth_method": "client_secret_basic"
}
```
The response returns `client_id`, `client_secret`, `registration_client_uri` and `registration_access_token`.

## Before production
- Dynamically registered clients need a persistent store; add `Duende.IdentityServer.Configuration.EntityFramework` and `.AddClientConfigurationStore()`.
- Add a custom `DynamicClientRegistrationValidator` to restrict grant types, require HTTPS redirect URIs and enforce PKCE.
