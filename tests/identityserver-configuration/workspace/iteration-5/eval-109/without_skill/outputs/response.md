# Parameterized Scopes (`transaction:abc123`)

IdentityServer lets you plug in a custom scope parser to handle scopes that carry a parameter, like `transaction:abc123`. You implement a parser, register it, and then read the extracted value in your profile service to emit a claim.

## 1. The Scope Parser

Implement `IScopeParser`. Its job is to turn each raw scope string into a parsed scope with a name and a parameter value.

```csharp
using Duende.IdentityServer.Validation;

public class TransactionScopeParser : IScopeParser
{
    public ParsedScopesResult ParseScopeValues(IEnumerable<string> scopeValues)
    {
        var result = new ParsedScopesResult();

        foreach (var scope in scopeValues)
        {
            if (scope.StartsWith("transaction:"))
            {
                var parameter = scope.Substring("transaction:".Length);
                if (string.IsNullOrEmpty(parameter))
                {
                    result.Errors.Add(new ParsedScopeValidationError(scope, "missing transaction id"));
                }
                else
                {
                    result.ParsedScopes.Add(new ParsedScopeValue(scope, "transaction", parameter));
                }
            }
            else
            {
                // pass through normal scopes unchanged
                result.ParsedScopes.Add(new ParsedScopeValue(scope));
            }
        }

        return result;
    }
}
```

## 2. Register the Parser

```csharp
var idsvrBuilder = builder.Services.AddIdentityServer()
    .AddInMemoryApiScopes(new[]
    {
        new ApiScope("transaction", "Transaction access")
    })
    .AddInMemoryClients(Config.Clients);

idsvrBuilder.AddScopeParser<TransactionScopeParser>();
```

Note that you register the base `transaction` scope, not the full `transaction:abc123` string — the parameter is provided per request.

## 3. Emit the Value as a Claim in `IProfileService`

```csharp
using System.Security.Claims;
using Duende.IdentityServer.Models;
using Duende.IdentityServer.Services;

public class TransactionProfileService : IProfileService
{
    public Task GetProfileDataAsync(ProfileDataRequestContext context)
    {
        // Find the requested transaction scope and pull the id out of it
        var transactionScope = context.RequestedScopes
            .FirstOrDefault(s => s.StartsWith("transaction:"));

        if (transactionScope is not null)
        {
            var transactionId = transactionScope.Substring("transaction:".Length);
            context.IssuedClaims.Add(new Claim("transaction_id", transactionId));
        }

        return Task.CompletedTask;
    }

    public Task IsActiveAsync(IsActiveContext context) => Task.CompletedTask;
}
```

Register it:

```csharp
builder.Services.AddTransient<IProfileService, TransactionProfileService>();
```

## Summary

- A custom `IScopeParser` extracts the parameter from `transaction:abc123`.
- Register it with `AddScopeParser<T>()`, and register only the base `transaction` scope.
- In the profile service, locate the requested transaction scope and emit the extracted id as a `transaction_id` claim.
