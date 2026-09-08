# Attaching the User's Access Token to a gRPC Client

Register the typed gRPC client with `AddGrpcClient<T>()` and chain `AddUserAccessTokenHandler()` — the handler acquires the current user's access token (refreshing it when needed) and attaches it to every gRPC call automatically. This requires OIDC user token management to be configured.

## `Program.cs`

```csharp
using Duende.AccessTokenManagement.OpenIdConnect;

var builder = WebApplication.CreateBuilder(args);

// --- Cookie + OIDC authentication ---
builder.Services.AddAuthentication(options =>
    {
        options.DefaultScheme = "cookie";
        options.DefaultChallengeScheme = "oidc";
    })
    .AddCookie("cookie")
    .AddOpenIdConnect("oidc", options =>
    {
        options.Authority = "https://sts.example.com";
        options.ClientId = "webapp";
        options.ClientSecret = "secret";
        options.ResponseType = "code";
        options.Scope.Add("openid");
        options.Scope.Add("profile");
        options.Scope.Add("offline_access");
        options.SaveTokens = true; // required for user token management
    });

// ✅ Prerequisite — registers user token management services
builder.Services.AddOpenIdConnectAccessTokenManagement();

// ✅ Typed gRPC client that attaches the current user's access token automatically
builder.Services.AddGrpcClient<Greeter.GreeterClient>(o =>
    {
        o.Address = new Uri("https://grpc.example.com");
    })
    .AddUserAccessTokenHandler();

var app = builder.Build();
app.Run();
```

## Usage

Inject the typed client — no token code at the call site:

```csharp
public sealed class GreetingService(Greeter.GreeterClient greeter)
{
    public async Task<string> SayHelloAsync(string name)
    {
        // The user's access token is attached to the gRPC metadata automatically
        var reply = await greeter.SayHelloAsync(new HelloRequest { Name = name });
        return reply.Message;
    }
}
```

## Why this works

- **`AddGrpcClient<Greeter.GreeterClient>()`** registers the typed gRPC client pointing at the downstream endpoint (`https://grpc.example.com`).
- **`.AddUserAccessTokenHandler()`** adds the same delegating handler used for HTTP clients; on each call it fetches the logged-in user's access token from token management (silently refreshing via the refresh token if expired) and puts it on the request as a bearer credential.
- **`AddOpenIdConnectAccessTokenManagement()`** is the prerequisite that makes user tokens available; with `SaveTokens = true` and `offline_access`, tokens are persisted and refreshable.

> If the downstream gRPC service should be called with a **machine identity** instead of the user's token, chain `.AddClientAccessTokenHandler()` instead of `.AddUserAccessTokenHandler()`.
