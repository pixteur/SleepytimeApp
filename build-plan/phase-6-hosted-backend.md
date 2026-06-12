# Phase 6 — Hosted Backend (product phase)

**Goal:** Turn SleepytimeApp from a BYO-key app into a **product**: a hosted service holds the AI keys, runs server-side safety, offers premium voices, syncs across devices, and handles billing — all behind the interfaces the app already uses.

> Trigger this phase only when validating SleepytimeApp as a commercial product. Everything here sits behind existing abstractions, so the app changes are small; the *operational and legal* surface is the real work.

## Tasks

### Backend service
- [ ] Stand up an API service that holds provider keys (Claude/OpenAI/Gemini) server-side.
- [ ] Implement `HostedProvider` (`AiProvider`) in the app — a thin client to that service. Drop-in; story engine unchanged.
- [ ] Server-side **safety** mirror of `SafetyGuard` (don't trust the client) + abuse/rate limiting.
- [ ] Quotas/usage metering per account.

### Accounts, sync, billing
- [ ] Parent accounts + auth (the app's *child profiles* stay a local concept under a parent account).
- [ ] `StorageRepo` cloud-sync adapter (encrypted in transit + at rest; merge strategy from [../docs/data-model.md](../docs/data-model.md)).
- [ ] Subscription/billing (store IAP on iOS/macOS; web/Stripe elsewhere).
- [ ] Premium hosted **voices** (curated `TtsProvider`) bundled in subscription.

### Compliance & privacy (BLOCKER — must precede any child-data transmission)
- [ ] Privacy policy + terms; data-processing records.
- [ ] **Verifiable parental consent** flow.
- [ ] **COPPA** (US), **GDPR-K** (EU), and other regional requirements for children's data.
- [ ] Data minimization, retention, and deletion (right-to-erasure) flows.
- [ ] Security review / pen test before launch.

## Exit criteria
- Users can subscribe and use the app with **no API key of their own**, with stories generated and safety-checked server-side, optional cross-device sync, and premium voices — all legally compliant for children's data.

## Dependencies
- A polished, validated app from Phases 0–5.

## Notes
- The whole point of the earlier architecture: this phase is *additive*. `AiProvider`, `TtsProvider`, and `StorageRepo` already abstract exactly what the hosted service replaces.
- Do **not** transmit any child data until the compliance checklist is complete. See [../docs/safety.md](../docs/safety.md).
