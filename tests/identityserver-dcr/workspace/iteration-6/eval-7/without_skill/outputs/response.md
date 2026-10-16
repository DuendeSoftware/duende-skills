# Separate DCR host

Create a new ASP.NET Core app hosting only the Configuration API, authenticating callers against https://identity.example.com.

```bash
dotnet new web -n DcrHost
dotnet add package Duende.IdentityServer.Configuration
dotnet add package Microsoft.AspNetCore.Authentication.JwtBearer
```

```csharp
var builder = WebApplication.CreateBuilder(args);

builder.Services.AddIdentityServerConfiguration(opt =>
{
    opt.LicenseKey = builder.Configuration["IdentityServer:LicenseKey"];
})
.AddClientConfigurationStore();   // must use the SAME database IdentityServer reads

builder.Services.AddAuthentication("token")
    .AddJwtBearer("token", o =>
    {
        o.Authority = "https://identity.example.com";
        o.MapInboundClaims = false;
        o.TokenValidationParameters.ValidateAudience = false;
        o.TokenValidationParameters.ValidTypes = new[] { "at+jwt" };
    });

builder.Services.AddAuthorization(o => o.AddPolicy("DCR", p =>
    p.RequireAuthenticatedUser().RequireClaim("scope", "IdentityServer.Configuration")));

var app = builder.Build();
app.UseAuthentication();
app.UseAuthorization();
app.MapDynamicClientRegistration().RequireAuthorization("DCR");
app.Run();
```

Points:
- The DCR host and IdentityServer must share the client **database** (EF configuration store); in-memory cannot work across processes.
- Use the same connection string and EF packages in both apps.
- `dcr.manager` stays in IdentityServer, gets tokens from identity.example.com, then calls the DCR host's `/connect/dcr`.
- Host it behind HTTPS (e.g. https://dcr.example.com) and restrict network access.
- Consider setting the issuer/authority explicitly for any metadata in responses.
