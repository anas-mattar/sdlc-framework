# External API Authentication Patterns

## Supported Patterns

Supported external API authentication patterns:

- API Key
- OAuth2 Client Credentials
- JWT Bearer
- mTLS when required

## Forbidden

Do not:

- Store username/password in source code
- Store API keys in source code
- Log tokens
- Return tokens to frontend
- Put secrets in configuration files committed to source (e.g. `appsettings.json`, `.env`)

## API Key

Use configuration/secret storage.

Recommended header:

```text
X-API-Key
```

The exact header must be defined in the API contract.

## OAuth2 Client Credentials

Required contract fields:

- Token endpoint
- Client ID config key
- Client secret storage
- Scope
- Token expiry handling

Tokens should be cached until expiry.

## JWT Bearer

Use only when provider requires it.

Required:

- Issuer
- Audience
- Signing key source
- Expiry policy

## Secret Rotation

Every integration should document:

- Who owns the secret
- How to rotate it
- Where it is stored
- How to test after rotation
