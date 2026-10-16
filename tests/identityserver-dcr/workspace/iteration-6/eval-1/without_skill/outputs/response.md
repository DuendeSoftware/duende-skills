# Adding Dynamic Client Registration (DCR)

DCR lives in the Duende IdentityServer **Configuration API** package.

## 1. Package
```bash
dotnet add package Duende.IdentityServer.Configuration
```

## 2. Service registration
```csharp
builder.Services.AddIdentityServerConfiguration()
    .AddInMemoryClientConfigurationStore();   // dev only; use the EF store for production
```

## 3. Authentication and endpoint mapping
The endpoint is `POST /connect/dcr`. Your `dcr.manager` client and `IdentityServer.Configuration` scope already exist; callers present a bearer token.
```csharp
builder.Services.AddAuthentication("token")
    .AddJwtBearer("token", o =>
    {
        o.Authority = "https://identity.example.com";
        o.MapInboundClaims = false;
        o.TokenValidationParameters.ValidateAudience = false;
        o.TokenValidationParameters.ValidTypes = new[] { "at+jwt" };
    });

builder.Services.AddAuthorization(o =>
    o.AddPolicy("DCR", p => p.RequireAuthenticatedUser()
                             .RequireClaim("scope", "IdentityServer.Configuration")));

var app = builder.Build();
app.UseStaticFiles();
app.UseRouting();
app.UseIdentityServer();
app.UseAuthentication();
app.UseAuthorization();

app.MapRazorPages();
app.MapDynamicClientRegistration().RequireAuthorization("DCR");
```

## 4. Test
Get a token for `dcr.manager` (client credentials, scope `IdentityServer.Configuration`), then:
```http
POST https://identity.example.com/connect/dcr
Authorization: Bearer <token>
Content-Type: application/json

{ "redirect_uris": ["https://client.example.com/cb"], "grant_types": ["authorization_code"], "client_name": "Demo" }
```
The response contains the generated `client_id`.

In-memory storage loses registered clients on restart, so switch to the EF store before production.
