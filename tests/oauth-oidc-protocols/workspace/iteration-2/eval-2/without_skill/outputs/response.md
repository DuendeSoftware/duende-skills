# Authorization Code Flow with PKCE

## What is PKCE?

PKCE (Proof Key for Code Exchange) is a security extension for the OAuth 2.0 authorization code flow. It was originally designed for mobile and native apps but is now recommended for all OAuth clients.

## Step-by-Step Flow

### 1. Generate Code Verifier and Challenge

The client generates a random `code_verifier` string and computes a `code_challenge` by hashing it with SHA256:

```
code_verifier = random_string(43 to 128 characters)
code_challenge = BASE64URL(SHA256(code_verifier))
```

### 2. Redirect to Authorization Endpoint

The client redirects the user to the authorization server:

```
GET /authorize?
  response_type=code
  &client_id=my-app
  &redirect_uri=https://myapp.com/callback
  &scope=openid profile
  &state=random_state
  &code_challenge=<hashed_value>
  &code_challenge_method=S256
```

The `code_challenge` and `code_challenge_method=S256` parameters tell the server PKCE is being used.

### 3. User Authenticates

The user logs in at the authorization server and consents to the requested permissions.

### 4. Authorization Code Callback

The server redirects back to the client with an authorization code:

```
https://myapp.com/callback?code=AUTH_CODE&state=random_state
```

### 5. Exchange Code for Tokens

The client sends the authorization code along with the original `code_verifier` to the token endpoint:

```
POST /token
  grant_type=authorization_code
  &code=AUTH_CODE
  &redirect_uri=https://myapp.com/callback
  &client_id=my-app
  &code_verifier=<original_random_string>
```

### 6. Server Validates and Returns Tokens

The authorization server hashes the `code_verifier` and compares it to the stored `code_challenge`. If they match, it returns the tokens.

## Why PKCE is Necessary

PKCE prevents authorization code interception attacks. Without PKCE, if an attacker intercepts the authorization code (through a malicious app or network interception), they can exchange it for tokens. With PKCE, the attacker cannot produce the matching `code_verifier` because they only saw the hash (`code_challenge`), not the original value.

## In Practice

Most modern OAuth libraries handle PKCE automatically. In ASP.NET Core, the OpenID Connect middleware handles the code_verifier/code_challenge generation and exchange transparently.
