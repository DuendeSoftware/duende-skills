# Common DCR security mistakes (and how to harden against them)

Dynamic Client Registration is powerful but easy to misconfigure. Here are the most common anti-patterns and pitfalls, with the hardening step for each.

## 1. Exposing the DCR endpoint without authentication or authorization

The single most dangerous mistake. If `/connect/dcr` is reachable anonymously, anyone can register clients on your IdentityServer — including malicious ones with attacker-controlled redirect URIs.

**Harden:** Always secure the endpoint with an authorization policy. Require a valid bearer token with a dedicated scope and apply it to the endpoint:

```csharp
app.MapDynamicClientRegistration()
    .RequireAuthorization("dcr");
```

Never map `MapDynamicClientRegistration()` without a `RequireAuthorization(...)`.

## 2. Allowing dynamically registered clients to use any grant type

Letting registrants pick arbitrary grant types (e.g. `implicit`, `password`, or `client_credentials`) opens the door to insecure flows and privilege escalation.

**Harden:** Restrict allowed grant types in a custom `DynamicClientRegistrationValidator` (override `ValidateGrantTypesAsync`), typically permitting only `authorization_code`, and **enforce PKCE** by setting `RequirePkce = true` in `SetClientDefaultsAsync`. Also enforce HTTPS-only redirect URIs.

## 3. Using in-memory stores for DCR clients in production

In-memory client stores lose every dynamically registered client on restart and aren't shared across load-balanced instances, so registrations silently disappear.

**Harden:** Use a persistent (database-backed) store in production — the `Duende.IdentityServer.Configuration.EntityFramework` package with `AddClientConfigurationStore()`, or a custom `IClientConfigurationStore`. Never rely on in-memory stores for DCR clients in production.

## 4. Storing client secrets in plaintext

DCR issues generated secrets to registered clients. Persisting them in plaintext means a database compromise leaks usable credentials.

**Harden:** Store secrets **hashed, not plaintext** (e.g. Duende's `Secret(value.Sha256())`). Ensure your `IClientConfigurationStore` never writes raw secret values.

## 5. Trusting software statements from unknown issuers

Software statements are signed JWTs of pre-approved metadata. Accepting them without verifying the signature — or accepting unknown issuers — lets attackers forge "approved" client metadata.

**Harden:** Validate software statements against **trusted signing keys** and pin the expected issuer. Resolve keys from the trusted issuer's JWKS (never from the token itself), and reject statements from any unknown issuer or with an invalid signature. Do this by overriding `ValidateSoftwareStatementAsync`.

## Additional hardening

- **Restrict/validate redirect URIs** — require HTTPS and, where possible, an allow-list; open redirect URIs enable token theft.
- **Restrict allowed scopes** — don't let registrants request high-privilege scopes; constrain what a dynamically registered client may ask for.
- **Rate-limit and monitor** the endpoint to prevent registration abuse, and audit-log every registration.
- **Require a Business Edition license** — DCR is a Business Edition (or higher) feature; make sure you're licensed and running a supported version.
- **Short-lived caller tokens** — the access token used to call `/connect/dcr` should be tightly scoped and short-lived.

## Summary checklist

| Risk | Hardening |
| ---- | --------- |
| Open endpoint | `RequireAuthorization` with a scoped policy |
| Arbitrary grant types | Restrict grants + enforce PKCE in the validator |
| In-memory store | Persistent DB store (`AddClientConfigurationStore()`) |
| Plaintext secrets | Store hashed secrets only |
| Untrusted software statements | Validate signature + pin trusted issuer |
| Loose redirect URIs / scopes | Enforce HTTPS, allow-list, restrict scopes |
