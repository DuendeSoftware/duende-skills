# Shortening Token Lifetimes

Here are the updated token lifetimes for each client:

```csharp
new Client
{
    ClientId = "web_app",
    // ...
    AccessTokenLifetime = 300  // 5 minutes
},
new Client
{
    ClientId = "m2m_client",
    // ...
    AccessTokenLifetime = 600  // 10 minutes
},
new Client
{
    ClientId = "mobile_app",
    // ...
    AccessTokenLifetime = 300  // 5 minutes
}
```

For token cleanup, configure the operational store:

```csharp
builder.Services.AddIdentityServer()
    // ...
    .AddOperationalStore(options =>
    {
        options.EnableTokenCleanup = true;
        options.TokenCleanupInterval = 1800;  // 30 minutes
    });
```

Short-lived access tokens reduce the window of opportunity if a token is compromised. Use refresh tokens for maintaining longer sessions.
