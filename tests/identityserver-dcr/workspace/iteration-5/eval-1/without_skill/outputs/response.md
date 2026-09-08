# Adding Dynamic Client Registration to Duende IdentityServer

Dynamic Client Registration (DCR) implements RFC 7591, allowing clients to register themselves programmatically at a registration endpoint (typically `/connect/dcr`). Duende ships DCR support in a dedicated configuration package.

## 1. NuGet package

Duende provides the registration functionality in a separate package:

```bash
dotnet add package Duende.IdentityServer.Configuration
```

Add it next to your existing `Duende.IdentityServer` reference in `IdentityServer.csproj`.

## 2. Service registration

Register the configuration/DCR services in your DI container. Since you already have `AddIdentityServer()` set up, add the configuration services after it:

```csharp
builder.Services.AddIdentityServer()
    .AddInMemoryIdentityResources(/* ... */)
    .AddInMemoryApiScopes(/* ... */)
    .AddInMemoryClients(/* ... */);

// DCR / configuration services
builder.Services.AddIdentityServerConfiguration();
```

## 3. Map the endpoint

In the request pipeline, map the DCR endpoint so it becomes reachable:

```csharp
var app = builder.Build();

app.UseStaticFiles();
app.UseRouting();
app.UseIdentityServer();
app.UseAuthorization();

app.MapRazorPages();

// Expose the Dynamic Client Registration endpoint
app.MapDynamicClientRegistration();

app.Run();
```

## Testing

Once running, you can POST a registration request:

```http
POST /connect/dcr
Content-Type: application/json

{
  "client_name": "My App",
  "redirect_uris": ["https://myapp.example.com/callback"],
  "grant_types": ["authorization_code"],
  "response_types": ["code"]
}
```

The server responds with a generated `client_id` (and `client_secret` for confidential clients).

## Security note

You should protect the registration endpoint so that arbitrary callers can't register clients — for example by requiring a bearer token or placing it behind an authorization policy. Consider adding `.RequireAuthorization()` to the mapped endpoint and validating a registration scope.

That's the core wiring: add the package, call `AddIdentityServerConfiguration()`, and map the endpoint. Check the Duende documentation for the exact version compatibility and any licensing tier requirements for this feature.
