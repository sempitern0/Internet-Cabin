# Responding to a Stolen or Malicious Game Reupload

This is a **preparation and incident-response checklist**, not legal advice and not an automated copyright-enforcement tool. Consult the affected storefront's live reporting rules and qualified counsel when needed.

## Before an incident

Create a private `release-evidence/` location **outside the distributed game**. Retain:

- Publisher legal/contact identity, official domain and storefront account records.
- Dated source-control history and evidence of original work; avoid exposing unrelated proprietary material publicly.
- License/contract register for third-party music, fonts, models, engines, and open-source dependencies.
- Final authentic release binaries, version/build identifier, timestamp, original SHA-256 hashes, and signing certificate identity.
- Official store/product URLs, release announcements, developer blogs and publication timestamps.
- Optional asset watermarks and the private recovery method, tested on realistic compression/transcoding. A watermark alone is not proof.
- An appointed internal contact who can file copyright and platform security reports.

> [!CAUTION]
> Never upload private encryption/signing keys, unreleased full source, personal documents, customer data, or a complete malware sample to a public complaint or community post. Share only what a platform's trusted process needs.

## When a suspected reupload appears

1. **Preserve the observation.** Record its exact store URL, publisher/account name, product ID, first-seen UTC time, storefront screenshots, price, description, screenshots, download links, and the original game's corresponding official page.
2. **Reduce risk.** If the suspected download may contain malware, do not execute it on a development machine or personal account. Refer examination to a sandboxed security process and follow organizational incident-handling policies.
3. **Collect comparison evidence.** Document distinctive scenes, textures, dialogue, audio, version strings, public build details and any recoverable watermark. Keep original and suspect artifacts separate and record SHA-256 for chain-of-custody clarity.
4. **Verify rights first.** Confirm that the claim covers the developer's protectable original content, not MIT-licensed Nucleus files, Godot engine code, permissively licensed components, public-domain content or someone else's art/music.
5. **Use the storefront's official reporting channel.** Submit a concise factual copyright/infringement notice with ownership evidence, original publication information and suspected listing URLs. For malware or impersonation, use the platform's separate security/fraud category as applicable. EU Digital Services Act (DSA) and US DMCA processes depend on intermediary and jurisdiction.
6. **Keep an incident timeline.** Record every complaint reference, submission date, staff response, follow-up and outcome. Escalate through formal platform channels, not harassment, accusations without evidence or speculative public identification.
7. **Communicate safely.** Link the authentic store/download page, explain that an unauthorized build may be unsafe, and avoid linking directly to a suspected malware download.
8. **After removal or closure, improve controls.** Review exposed build assets, signing hygiene, public brand coverage and release-monitoring needs. If private keys leaked, revoke/rotate them and rebuild.

## Minimal incident record

| Field | Example/template |
| --- | --- |
| Incident ID | `2026-001` |
| Reported UTC | `YYYY-MM-DDThh:mm:ssZ` |
| Official game/store URL | `https://...` |
| Suspected listing URL and ID | `https://...` |
| Suspected publisher display name | As shown in the store |
| Authentic build version and SHA-256 | Exact archived release |
| Distinctive similarities | Specific, verifiable comparisons |
| Rights evidence | Original files/commits, licenses, contracts |
| Safety concern | Fraudulent identity, ads, suspected malware (label unverified observations) |
| Platform report reference | Ticket ID, submission timestamp |
| Current status | Open / under review / removed / resolved |

## Practical verification notes

- **Code signature:** can help players and stores distinguish the authentic signed publisher build. Do not claim an invalid signature by itself proves copied copyrighted content.
- **PCK encryption:** can increase the effort of extracting assets but does not leave durable attribution proof after a resource has been copied or modified.
- **Watermarking:** useful supporting evidence for specific image/audio assets when validated against transformations; inaccurate detections risk false claims.
- **Provenance and public history:** early official pages, dated developer updates and consistent distribution identity establish stronger supporting context than a single screenshot.

## Related Nucleus documentation

- [Protecting a Released Godot Game](game_protection_quickstart.md)
- [Distribution security architecture](../architecture/game_distribution_security.md)
- [Nucleus release packaging](releasing.md)

**Inspiration:** *The Clone Wars: Defending Godot Games From Reupload Scams* (user-provided GodotCon slide deck), especially pp. 11-21 on licenses, asset marks, response playbooks and public presence.
