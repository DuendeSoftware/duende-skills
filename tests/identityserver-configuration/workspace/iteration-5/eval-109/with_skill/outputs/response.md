# Parameterized Scopes (`transaction:abc123`)

Parameterized scopes carry a value alongside the scope name. You handle them by subclassing `DefaultScopeParser`, overriding `ParseScopeValue`, registering the parser with `AddScopeParser<T>()`, and reading the parsed parameter downstream in an `IProfileService` via `RequestedResources.ParsedScopes`.

## 1. The Scope Parser

```csharp
using Duende.IdentityServer.Validation;
using Microsoft.Extensions.Logging;

public class ParameterizedScopeParser : DefaultScopeParser
{
    public ParameterizedScopeParser(ILogger<DefaultScopeParser> logger) : base(logger)
    {
    }

    public override void ParseScopeValue(ParseScopeContext scopeContext)
    {
        const string transactionScopeName = "transaction";
        const string separator = ":";
        const string transactionScopePrefix = transactionScopeName + separator;

        var scopeValue = scopeContext.RawValue;

        if (scopeValue.StartsWith(transactionScopePrefix))
        {
            // "transaction:abc123" -> name "transaction", parameter "abc123"
            var parts = scopeValue.Split(separator, StringSplitOptions.RemoveEmptyEntries);
            if (parts.Length == 2)
            {
                scopeContext.SetParsedValues(transactionScopeName, parts[1]);
            }
            else
            {
                scopeContext.SetError("transaction scope missing transaction parameter value");
            }
        }
        else if (scopeValue != transactionScopeName)
        {
            // Delegate all non-transaction scopes to the default behavior
            base.ParseScopeValue(scopeContext);
        }
        else
        {
            // Bare "transaction" (no parameter) — ignore it
            scopeContext.SetIgnore();
        }
    }
}
```

## 2. Register the Parser (and a backing ApiScope for `transaction`)

```csharp
var idsvrBuilder = builder.Services.AddIdentityServer()
    .AddInMemoryApiScopes(new[]
    {
        // Register the BASE scope name only — NOT "transaction:abc123"
        new ApiScope("transaction", "Transaction-scoped access")
    })
    .AddInMemoryClients(Config.Clients);

// Plug in the custom parser
idsvrBuilder.AddScopeParser<ParameterizedScopeParser>();
```

> Note the static `ApiScope` is named `transaction` (the base name). The `:abc123` parameter is supplied at request time and extracted by the parser — you never register the parameterized value as a static scope.

## 3. Read the Parsed Parameter in `IProfileService`

```csharp
using System.Security.Claims;
using Duende.IdentityServer.Models;
using Duende.IdentityServer.Services;

public class TransactionProfileService : IProfileService
{
    public Task GetProfileDataAsync(ProfileDataRequestContext context)
    {
        var transaction = context.RequestedResources.ParsedScopes
            .FirstOrDefault(x => x.ParsedName == "transaction");

        if (transaction is not null)
        {
            // ParsedParameter holds "abc123" for the requested scope "transaction:abc123"
            context.IssuedClaims.Add(
                new Claim("transaction_id", transaction.ParsedParameter));
        }

        return Task.CompletedTask;
    }

    public Task IsActiveAsync(IsActiveContext context) => Task.CompletedTask;
}
```

Register the profile service:

```csharp
builder.Services.AddTransient<IProfileService, TransactionProfileService>();
```

## Summary

- **`ParseScopeValue(ParseScopeContext)`** is overridden on `DefaultScopeParser`; it uses `SetParsedValues(name, parameter)` for the transaction scope, `SetError(...)` when the parameter is missing, `SetIgnore()` for the bare name, and delegates everything else to `base`.
- **`AddScopeParser<ParameterizedScopeParser>()`** wires the parser into IdentityServer.
- In **`IProfileService`**, `context.RequestedResources.ParsedScopes.FirstOrDefault(x => x.ParsedName == "transaction")` locates the parsed scope, and `ParsedParameter` gives you the `abc123` value to emit as a claim.
- The parameterized value (`abc123`) is **never** a static `ApiScope` — only the base `transaction` scope is registered.
