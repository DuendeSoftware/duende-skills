# Common SAML Service Provider Validation Requirements

Validation errors when registering a SAML SP usually come down to a handful of required fields and binding constraints. For your SP (EntityId `https://hr.example.com`, ACS `https://hr.example.com/sso`), check the following:

## 1. EntityId

- Must be present and unique. It's the primary identifier the IdP uses to look up the SP, and it must match exactly what the SP sends in its AuthnRequest (`Issuer`) and metadata. A trailing-slash or case mismatch will cause "unknown service provider" errors.

## 2. Assertion Consumer Service (ACS) URL and binding

- You need at least one ACS endpoint.
- The ACS URL must be an absolute HTTPS URL and typically must match the SP's metadata.
- The **binding matters**: the ACS (where the assertion is delivered) generally uses **HTTP-POST**, because the assertion is too large and sensitive to send as a URL query parameter. Make sure the binding you configure on the ACS matches what the SP expects.

## 3. Certificates

- If you require signed AuthnRequests, the SP's signing certificate must be configured so signatures can be validated.
- Your IdP needs a valid signing certificate to sign assertions/responses.

## 4. Claims/attributes

- Make sure the SP is granted the scopes/claims it needs, otherwise the assertion may be rejected or unusable downstream.

## Typical fixes

1. Confirm EntityId matches the SP's Issuer exactly.
2. Set the ACS binding to HTTP-POST.
3. Ensure the ACS URL exactly matches the SP metadata (protocol, host, path, trailing slash).
4. Verify certificates line up on both sides.
5. Check NameID format compatibility with what the SP expects.

## Recommendation

Enable detailed logging on IdentityServer during SP registration/validation to see the specific validation message, and compare your SP configuration against its published metadata. The exact validation rules and property names depend on the SAML library you're using, so consult its documentation for the authoritative list.
