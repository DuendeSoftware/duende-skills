# gRPC Client with User Access Token

To register a gRPC client that automatically attaches the user's access token using Duende.AccessTokenManagement, use `AddGrpcClient<T>()` with the `AddUserAccessTokenHandler()` extension.

## Package References

```xml
<PackageReference Include="Duende.AccessTokenManagement.OpenIdConnect" Version="4.0.0" />
<PackageReference Include="Grpc.Net.ClientFactory" Version="2.67.0" />
```

## Program.cs

```csharp
using Duende.AccessTokenManagement;

var builder = WebApplication.CreateBuilder(args);

// ── Authentication: cookie + OIDC ──
builder.Services.AddAuthentication(options =>
    {
        options.DefaultScheme = "cookie";
        options.DefaultChallengeScheme = "oidc";
    })
    .AddCookie("cookie", options =>
    {
        options.Cookie.Name = "web";
        options.Events.OnSigningOut = async e =>
        {
            await e.HttpContext.RevokeRefreshTokenAsync();
        };
    })
    .AddOpenIdConnect("oidc", options =>
    {
        options.Authority = "https://sts.example.com";
        options.ClientId = "webapp";
        options.ClientSecret = "secret";
        options.ResponseType = "code";

        options.Scope.Clear();
        options.Scope.Add("openid");
        options.Scope.Add("profile");
        options.Scope.Add("grpc_api");
        options.Scope.Add("offline_access");

        options.SaveTokens = true;
    });

// ── Token management ──
builder.Services.AddOpenIdConnectAccessTokenManagement();

// ── gRPC client with user's access token ──
builder.Services.AddGrpcClient<Greeter.GreeterClient>(o =>
{
    o.Address = new Uri("https://grpc.example.com");
})
.AddUserAccessTokenHandler();

var app = builder.Build();

app.UseAuthentication();
app.UseAuthorization();

app.MapGet("/greet", async (Greeter.GreeterClient grpcClient) =>
{
    // ✅ The user's access token is automatically attached to the gRPC call
    var reply = await grpcClient.SayHelloAsync(new HelloRequest { Name = "World" });
    return Results.Ok(reply.Message);
}).RequireAuthorization();

app.Run();
```

## How It Works

- `AddGrpcClient<Greeter.GreeterClient>(...)` registers the typed gRPC client with `HttpClientFactory` and sets the downstream endpoint address.
- `.AddUserAccessTokenHandler()` chains a delegating handler that reads the current user's access token from the OIDC session (via `AddOpenIdConnectAccessTokenManagement()`) and attaches it as a Bearer token on every outgoing gRPC call.
- Token refresh is automatic — if the access token has expired and a refresh token is available (`offline_access`), the library refreshes it silently before attaching.
- This works the same way as `AddUserAccessTokenHandler()` on regular HTTP clients. gRPC clients use `HttpClientFactory` under the hood, so all the same token management handlers apply.
