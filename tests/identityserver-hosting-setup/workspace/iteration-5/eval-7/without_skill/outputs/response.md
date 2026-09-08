# Hosting Pattern and IssuerUri

## Hosting: prefer a separate host for IdentityServer

Even though co-hosting IdentityServer inside your main API reduces the number of things you deploy, I'd recommend running IdentityServer as its **own dedicated application**. It's your security-token service — it holds signing keys and issues credentials, so it deserves an isolated home.

The main reason is **attack surface**: putting your identity provider in the same process as a general-purpose API means any weakness in the API's code or dependencies is now adjacent to your token-signing keys. Keeping them separate gives you a clean security boundary, and it also lets you deploy, patch, and scale the two independently.

If your concern is deployment complexity, that's usually better handled by your container/orchestration setup (a second container/service in the same pipeline) rather than by merging the two apps.

## IssuerUri: set it explicitly to a stable value

For the issuer, my recommendation is to **set `IssuerUri` explicitly** to your canonical public URL, e.g.:

```csharp
builder.Services.AddIdentityServer(options =>
{
    options.IssuerUri = "https://identity.mycompany.com";
});
```

If you let it be inferred from the incoming request, the issuer can vary depending on how the server is reached (proxy, internal vs. external host, http vs. https), and since clients validate the `iss` claim against a fixed expected value, an inconsistent issuer leads to token-validation failures. Pinning it to one stable value keeps `iss` consistent across all environments and avoids those surprises.

Whichever you choose, make sure every client is configured with the exact issuer value that IdentityServer publishes in its discovery document.
