# Common Security Mistakes with Dynamic Client Registration

Here's a list of common security issues to watch out for when implementing DCR.

## 1. Not Securing the DCR Endpoint

The biggest mistake is leaving the registration endpoint open to anyone. Always require authentication and authorization on the DCR endpoint. Use a policy that checks for a valid token and appropriate scope.

## 2. Allowing Any Grant Type

If you allow clients to register with any grant type, they could register with `client_credentials` and access APIs without user involvement, or use `implicit` flow which is less secure. Restrict the allowed grant types and consider requiring PKCE for authorization code flows.

## 3. Not Validating Redirect URIs

Accept only HTTPS redirect URIs. Open redirect vulnerabilities are a major risk if you accept arbitrary redirect URIs.

## 4. Using In-Memory Storage

In-memory stores lose all registered clients on restart. Use a database-backed store for production deployments.

## 5. Not Hashing Secrets

Client secrets should be hashed before storage, just like passwords. Never store them in plaintext.

## 6. Trusting Any Software Statement

If you support software statements, make sure you validate the JWT signature against known signing keys. Don't accept statements from unknown issuers.

## 7. No Rate Limiting

Without rate limiting, an attacker could flood your DCR endpoint with registration requests, potentially exhausting resources.

## 8. Not Logging Registrations

Keep audit logs of all client registrations for security monitoring and compliance.
