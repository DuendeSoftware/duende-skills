# Tenant 'Acme' at https://login.example.com/t/acme (SQLite)

Caveat: I don't have reliable knowledge of a `Duende.Spaces` package API. The code below uses the shape I'd expect; names like `AddSpaces`, `UseSpaces` and the provisioning service are **assumptions** to verify against the package docs.

## Program.cs

```csharp
using Microsoft.EntityFrameworkCore;

var builder = WebApplication.CreateBuilder(args);
var cs = builder.Configuration.GetConnectionString("Spaces") ?? "Data Source=spaces.db";

builder.Services.AddRazorPages();

builder.Services.AddIdentityServer(options =>
    {
        options.EmitStaticAudienceClaim = true;
    })
    .AddConfigurationStore(o => o.ConfigureDbContext = b => b.UseSqlite(cs))
    .AddOperationalStore(o => o.ConfigureDbContext = b => b.UseSqlite(cs));

// Assumed API: path-based tenant resolution /t/{space}
builder.Services.AddSpaces(o =>
{
    o.PathPrefix = "/t";
    o.UseSqlite(cs);
});

var app = builder.Build();

app.UseStaticFiles();
app.UseSpaces();          // must run before routing/IdentityServer so the path base is set
app.UseRouting();
app.UseIdentityServer();
app.UseAuthorization();
app.MapRazorPages();

// Provisioning
using (var scope = app.Services.CreateScope())
{
    var spaces = scope.ServiceProvider.GetRequiredService<ISpaceManager>(); // assumed
    if (!await spaces.ExistsAsync("acme"))
        await spaces.CreateAsync(new Space { Name = "acme", DisplayName = "Acme" });
}

app.Run();
```

## appsettings.json
```json
{ "ConnectionStrings": { "Spaces": "Data Source=spaces.db" } }
```

## Notes
- Middleware order: static files → tenant resolution → routing → IdentityServer → authorization → endpoints.
- Discovery should then be at `https://login.example.com/t/acme/.well-known/openid-configuration`, and the issuer should include `/t/acme`; do not set a fixed `IssuerUri`.
- Run EF migrations for the config/operational stores (SQLite) before starting; in production provision spaces via an admin endpoint/CLI rather than at startup.
- Register clients per space, with redirect URIs for that tenant's apps.
