# DCR Security Best Practices

Common mistakes to avoid:

1. **No authentication on DCR endpoint** - Always require authorization. Use JWT bearer with a scope check.

2. **Allowing all grant types** - Restrict to authorization_code and enforce PKCE to prevent malicious client registration.

3. **In-memory stores** - Don't use in-memory for production. Clients disappear on restart.

4. **Software statement validation** - Always validate the signature and issuer of software statements. Don't accept JWTs from unknown issuers.

5. **Redirect URI validation** - Enforce HTTPS and validate against known patterns.

Make sure to log all DCR requests for auditing and rate-limit the endpoint.
