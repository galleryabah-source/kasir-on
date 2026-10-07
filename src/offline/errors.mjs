export class OfflineDomainError extends Error {
  constructor(code, message, details = {}) { super(message); this.name = "OfflineDomainError"; this.code = code; this.details = details; }
}
export const ERR = Object.freeze({
  DEVICE_NOT_TRUSTED: "DEVICE_NOT_TRUSTED",
  SHIFT_NOT_OPEN: "SHIFT_NOT_OPEN",
  INVALID_ORDER: "INVALID_ORDER",
  INVALID_PAYMENT: "INVALID_PAYMENT",
  SYNC_CONFLICT: "SYNC_CONFLICT"
});
