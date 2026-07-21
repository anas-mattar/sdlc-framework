# External API Contract Template

Use this template for every external API integration (the project's external systems are listed in `docs/project/`).

## 1. Integration Name

Name:

## 2. Business Purpose

Explain why the project integrates with this API.

## 3. Owner

Business owner:

Technical owner:

Vendor contact:

## 4. Systems

Source system:

Target system:

Direction:

- Project -> External
- External -> Project
- Bidirectional

## 5. Environment URLs

Do not store secrets here.

| Environment | Base URL Config Key | Notes |
|---|---|---|
| DEV |  |  |
| UAT |  |  |
| PROD |  |  |

## 6. Authentication

Authentication type:

- API Key
- OAuth2 Client Credentials
- JWT Bearer
- mTLS
- Other

Token endpoint:

Required scopes:

Secret storage location:

## 7. Endpoint List

| Method | Path | Purpose | Auth Required |
|---|---|---|---|
| GET |  |  | Yes |
| POST |  |  | Yes |

## 8. Request Schema

```json
{
  "example": "value"
}
```

## 9. Response Schema

```json
{
  "example": "value"
}
```

## 10. Error Response Schema

```json
{
  "code": "",
  "message": ""
}
```

## 11. Retry Policy

Retry allowed:

Retry count:

Retry status codes:

Backoff strategy:

## 12. Timeout Policy

Timeout seconds:

## 13. Idempotency

Required:

Idempotency key field:

Duplicate handling rule:

## 14. Correlation ID

Header name:

Log field:

## 15. Audit Logging

Must store:

- Request reference
- Correlation ID
- Status
- Timestamp
- Response summary
- Error message

Payload storage rule:

## 16. Security

Sensitive fields:

Masking requirements:

PII handling:

## 17. Testing

Test cases:

- Success
- Validation failure
- Unauthorized
- Timeout
- Duplicate request
- Provider unavailable
