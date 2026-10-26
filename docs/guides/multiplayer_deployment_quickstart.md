# Multiplayer Deployment and Cost Quickstart

This guide begins after localhost authority works.

It answers the practical production questions around where to run a Godot
server, how to start it, what to expose, and what the first monthly bills look
like.

Pricing is a **snapshot from 6 October 2026**. Cloud prices change; always verify
the provider before spending money. Prices below exclude taxes and optional
services unless the provider states otherwise.

## 1. Start with one Linux VM

For an early public test, prefer:

```text
one Linux VM
one public address
one game-server process
one UDP game port
systemd supervision
```

over an orchestrated cluster.

Use a region close to the majority of testers. Physical distance affects latency
more directly than brand choice.

## 2. Current entry-level cost references

Examples from official provider pricing on 6 October 2026:

| Provider | Example Linux VM | Monthly cap | Included transfer |
| --- | --- | ---: | ---: |
| DigitalOcean | 1 GiB / 1 vCPU Basic | $6 | 1,000 GiB |
| DigitalOcean | 2 GiB / 1 vCPU Basic | $12 | 2,000 GiB |
| DigitalOcean | 4 GiB / 2 vCPU Basic | $24 | 4,000 GiB |
| AWS Lightsail | 1 GB Linux + public IPv4 | $7 | 2 TB |
| AWS Lightsail | 2 GB Linux + public IPv4 | $12 | 3 TB |
| AWS Lightsail | 4 GB Linux + public IPv4 | $24 | 4 TB |

Official references:

- DigitalOcean Droplets: https://www.digitalocean.com/pricing/droplets
- Amazon Lightsail bundles:
  https://docs.aws.amazon.com/lightsail/latest/userguide/amazon-lightsail-bundles.html

Hetzner and other EU providers can also be attractive, but plan availability and
pricing have changed during 2026. Check the current regional price/availability
rather than copying an old tutorial value.

## 3. Which size should I choose?

Start from measured server load, not client GPU requirements.

For a lightweight prototype, 1-2 GB can be enough to discover the real shape of
the workload. 2-4 GB gives more room for a typical early co-op server.

CPU is frequently the first gameplay limit because the server still runs:

```text
physics
AI
pathfinding
combat/gameplay simulation
serialization/network processing
persistence work
```

A shared-vCPU VM is fine for development when occasional CPU contention is
acceptable. Move to stronger/dedicated CPU when server frame-time variance is a
measured problem.

## 4. Estimate bandwidth instead of guessing

Measure outbound server bandwidth per connected player under a representative
match.

A useful rough monthly estimate is:

```text
GB/month ~= outbound_kbps_per_player
           * average_concurrent_players
           * 3600
           * hours_per_month
           / 8
           / 1,000,000
```

Example at 730 hours/month:

```text
20 kbps/player * 20 average players
    ~= 131 GB/month outbound

20 kbps/player * 100 average players
    ~= 657 GB/month outbound
```

This is only a planning estimate. Real traffic includes protocol overhead,
spikes, reconnects, state changes and non-player traffic. Measure the actual
process/network interface before choosing a transfer plan.

## 5. Server command line

Use Godot user arguments after `--` so the engine does not consume them.

Example:

```bash
./NucleusServer.x86_64 -- \
  --server \
  --port=42069 \
  --max-clients=16 \
  --bind=0.0.0.0
```

For local development with the editor binary:

```bash
godot --headless --path . -- \
  --server \
  --port=42069 \
  --max-clients=16
```

The example bootstrap under `examples/networking/` parses this simple shape.

## 6. Firewall

For ENet on port `42069`, the game-facing rule is UDP:

```text
allow 42069/udp
```

Administration commonly needs SSH:

```text
allow 22/tcp
```

Restrict SSH source addresses where practical, use SSH keys, and do not expose
unrelated database/admin ports publicly just because the VM is a game server.

Cloud-provider firewalls and the guest OS firewall are separate layers. Both may
need to allow the endpoint.

## 7. Run as an unprivileged service

Create a dedicated OS user, for example:

```text
nucleus
```

Own the deployed files with that account and run the process under systemd.

A sample unit is included at:

```text
examples/networking/nucleus-server.service.example
```

Useful commands:

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now nucleus-server
sudo systemctl restart nucleus-server
sudo systemctl status nucleus-server
journalctl -u nucleus-server -f
```

## 8. What belongs in environment/secrets?

Safe command-line configuration includes ordinary non-secret server policy such
as:

```text
port
bind address
max clients
map/playlist identifier
region label
log level
```

Do not commit:

```text
private signing keys
provider client secrets
production database passwords
long-lived admin tokens
```

Use the deployment platform's environment/secret facilities and ensure the game
never prints secrets into logs.

## 9. Persistence changes the cost/risk model

An ephemeral match server can die and restart without storing durable state.

A persistent world may need:

```text
database or durable files
backup policy
restore procedure
schema/version migrations
write authorization
```

Do not add a database solely because the game is online. Add durable storage
when the product actually owns durable multiplayer state.

## 10. Relay and matchmaking are separate budgets

A dedicated public server does not inherently need a relay because clients
connect to a known public endpoint.

A listen-server game often needs a provider solution when hosts are behind
CGNAT or when manual port forwarding is unacceptable.

Provider P2P/relay/matchmaking pricing and platform eligibility can change and
may depend on storefront accounts or commercial agreements. Treat those as a
separate provider decision, not as part of `NucleusNetworkHandler`.

## 11. What should I monitor?

At minimum:

```text
process uptime/restarts
CPU
resident memory
server frame/physics time
connected peers
network bytes/packets
join failures
disconnects
intent rejection/rate-limit counts
persistent save/database errors
```

The purpose is capacity planning and fault diagnosis, not collecting player data
without a product/privacy reason.

## 12. When one VM stops being enough

Scale only after you know what "one server" means for your game.

Common models are:

```text
one process = one match
one process = several small matches
one process = one persistent shard/world
```

Then capacity can be reasoned about:

```text
usable matches per VM
* players per match
* target utilization
= approximate player capacity per VM
```

Only then does autoscaling/orchestration become a concrete engineering problem.

## 13. A realistic prototype budget

A reasonable early budget can be:

```text
private localhost/listen-server development
    infrastructure: $0

small public playtest
    VM: about $6-$24/month in the examples above
    domain: optional
    database: $0 if not needed
    relay/matchmaking: $0 if not needed

larger test
    stronger/multiple VMs
    + storage/database if product requires it
    + observability retention
    + provider/relay charges when applicable
```

The engineering time spent operating the service can exceed the raw VM bill.
Keep the first deployment boring.

## 14. Production gate

Before spending on scale, require evidence for:

```text
one authoritative server survives representative load
bandwidth per player is measured
join/disconnect/reconnect is reliable
auth/admission policy exists
persistence recovery is tested when applicable
logs make failures diagnosable
server update/rollback is documented
```

## Related documentation

- [`tutorials/networking.md`](tutorials/networking.md)
- [`networking_quickstart.md`](networking_quickstart.md)
- [`online_replication_quickstart.md`](online_replication_quickstart.md)
- [`../modules/networking.md`](../modules/networking.md)
- [`../modules/online_replication.md`](../modules/online_replication.md)
