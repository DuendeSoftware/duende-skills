# Shortening Access Token Lifetimes

Here's how to reduce the token lifetimes for your clients:

```csharp
new Client
{
    ClientId = "web_app",
    // ... existing config ...
    AccessTokenLifetime = 300 // 5 minutes
},
new Client
{
    ClientId = "m2m_client",
    // ... existing config ...
    AccessTokenLifetime = 600 // 10 minutes
},
new Client
{
    ClientId = "mobile_app",
    // ... existing config ...
    AccessTokenLifetime = 300 // 5 minutes
}
```

For token cleanup, you'll want to configure the operational store:

```csharp
builder.Services.AddIdentityServer()
    // ... clients, scopes, etc. ...
    .AddOperationalStore(options =>
    {
        options.EnableTokenCleanup = true;
        options.TokenCleanupInterval = 1800; // 30 minutes
    });
```

Short-lived tokens reduce the window of risk if a token is compromised. Use refresh tokens to maintain session continuity without long-lived access tokens.
