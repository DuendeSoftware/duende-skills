# Authorization Code Flow with PKCE

## What is PKCE?

PKCE (Proof Key for Code Exchange) is a security extension for the authorization code flow. It prevents authorization code interception attacks.

## Steps

### 1. Generate Code Verifier and Challenge
The client creates a random string (code_verifier) and computes its SHA256 hash (code_challenge).

### 2. Authorization Request
The client redirects to the authorization endpoint with the code_challenge:
```
/authorize?response_type=code&client_id=app&code_challenge=xxx&code_challenge_method=S256
```

### 3. User Authentication
The user logs in at the identity provider.

### 4. Authorization Code Returned
The server redirects back with an authorization code.

### 5. Token Exchange
The client sends the authorization code AND the original code_verifier to the token endpoint:
```
POST /token
grant_type=authorization_code&code=xxx&code_verifier=yyy
```

### 6. Verification
The server hashes the received code_verifier and compares it to the stored code_challenge. If they match, tokens are issued.

## Why PKCE Works

An attacker who intercepts the authorization code can't exchange it because they don't have the code_verifier. The code_verifier is never sent through the browser — only through the secure backchannel.

## In Practice

Most modern OIDC client libraries handle PKCE automatically. In ASP.NET Core, the OpenID Connect handler includes PKCE support.
