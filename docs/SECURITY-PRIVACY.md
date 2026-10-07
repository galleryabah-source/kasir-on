# KASIRA Security & Privacy

## Threat priorities
- stolen POS device
- credential compromise
- tenant isolation failure
- privilege escalation
- duplicate payment processing
- malicious discount/void/refund
- exposed customer PII
- leaked secrets
- tampered audit trail

## Controls

### Identity
- short-lived access tokens
- refresh-token rotation
- MFA for privileged users
- PIN for fast cashier session switching

### Device
- device registration
- device trust
- remote revoke
- app version enforcement when required

### Authorization
- role + capability
- approval matrix
- outlet scope
- warehouse scope
- high-risk action policies

### Data
- TLS
- encryption at rest
- secret manager
- PII classification
- retention policy
- export/anonymization workflow

### Audit
All high-risk actions write immutable audit entries.

## Payment

KASIRA must not store card PAN/CVV. Payment integrations should use provider tokenization/hosted flows and store only provider references required for reconciliation.

## Indonesia privacy posture

Blueprint mendukung purpose limitation, data minimization, access logging, retention/deletion policy, and incident response sesuai regulasi privasi Indonesia yang berlaku.
