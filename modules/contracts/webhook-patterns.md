# Webhook Patterns

## Purpose

Use this file for all incoming webhook integrations.

## Rules

Incoming webhooks must:

- Validate signature
- Validate timestamp when provided
- Be idempotent
- Store raw payload
- Store processing result
- Return quickly
- Process business logic outside the controller/handler

## Recommended Flow

```text
Webhook Endpoint
  -> Validate signature
  -> Store raw payload
  -> Check duplicate event id
  -> Enqueue processing
  -> Return 200/202
  -> Background processor applies business logic
```

## Webhook Table

Recommended table (column types are illustrative — adapt to the project's database):

```text
WebhookEvent
- Id (auto-increment integer)
- Provider (string, 100)
- EventId (string, 200)
- EventType (string, 100)
- Signature (string, 500)
- Payload (large text)
- ReceivedAt (timestamp)
- ProcessedAt (timestamp, nullable)
- Status (string, 50)
- ErrorMessage (large text, nullable)
- RetryCount (integer)
```

## Idempotency

Use provider event ID when available.

If no provider event ID exists, calculate a fingerprint from:

- Provider
- Event type
- Source reference
- Payload hash

## Security

Reject webhook when:

- Signature invalid
- Timestamp too old
- Required headers missing
- Payload schema invalid

## Processing

Webhook processors must be safe to run multiple times.

Do not create duplicate business records (e.g. journals, payments, invoices) from repeated webhook events.
