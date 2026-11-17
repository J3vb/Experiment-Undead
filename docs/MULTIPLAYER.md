# Multiplayer plan (P7 co-op, P8 server, P9 town)

How co-op works and the order it gets built. Big decisions also go in
`docs/DECISIONS.md`. "Provisional" means picked by an agent and easy to change.

## Decided

| Topic | Choice | Who |
|---|---|---|
| Engine networking | Godot high-level multiplayer: ENet over UDP, `MultiplayerSpawner`, `MultiplayerSynchronizer`, `@rpc`. No netfox. | Architecture doc |
| Server | Self-hosted dedicated server (headless export of this project), max 8 players. No accounts, no master server, no anti-cheat. | Person, 2026-11-14 |
| Authority | **Trusted client.** Each player's PC moves its own character and decides its own hits, then tells the server. The server owns everything shared: zombies, waves, health, points, XP, loot, doors and machines. | Person, 2026-11-15 |
| Saves | Characters and stash stay on the player's PC (`user://characters/`). The server rolls loot and sends grants; the client saves them. | Architecture doc |
| Loot | Kept on death. Personal loot, no trading in v1. | Design doc |

Why trusted client: friends-only servers, CoD-style instant hits at any ping,
and far less code than server-side movement with prediction and lag
compensation. A stricter server can come later for public servers: gameplay
already reads `InputFrame`s, so the server could replay them.

## Provisional picks

- **One code path.** Solo is "server with one player and no open port" (Godot's
  offline peer counts as the server). Host and play = same scene with an open
  port (listen server). Dedicated = same `GameSession` with no local player.
- **Players.** `PlayerSpawner` (a `MultiplayerSpawner`) makes one `Player` per
  peer, named after the peer id, with that peer as its authority. The player's
  `net_id` is the peer id. A `MultiplayerSynchronizer` in `player.tscn` sends
  position, body yaw, head pitch and crouch from the owner to everyone
  (teammate animations read them, F-41).
- **Scene paths match on every peer.** The match is always `/root/GameSession`
  (clients change scene to it; the dedicated server adds it next to itself).
- **Joining.** The client opens its connection inside `GameSession._ready()`,
  after the map exists, so spawns from the server never arrive early.
- **One match per server** until the town (P9). Port 7777 UDP.
- **No interpolation buffer yet.** Positions sync at the physics rate (60 Hz)
  and physics interpolation smooths the rest. Add a buffer only if remote
  players look jittery in a play-test.

## Who owns what

| Thing | Owner | How others learn about it |
|---|---|---|
| Own movement, look, weapon switching, recoil | Owning client | Synchronizer (pose), RPC to server for fire events |
| Hits on zombies | Owning client claims, server applies | RPC `claim_hit(zombie net_id, zone, damage info)`; server checks range and that the zombie lives |
| Zombies (spawn, AI, death) | Server | `MultiplayerSpawner` + synchronizer (position, yaw, state) |
| Player health, downed, death | Server | Synced to all (HUD, revive prompts) |
| Points, wall buys, machines, doors | Server | Client sends a request to `InteractionSync`; server checks sender, range, rate and gun facts, then runs the same `interact()`. World state goes to all (late joiners get a snapshot); guns and ammo reach the buyer as grants |
| Waves, round number, power-ups | Server | Synced to all |
| Run XP and loot rolls | Server (`ProgressionService`) | Grant RPC to the owning client, which saves it |
| Equipped gear and item guns | Owning client picks; server owns the effects | `PlayerStateSync.submit_loadout` on spawn and every Pack equip; the server applies gear, loot luck and item on-hit effects (leech, points per hit) from its copy |
| Cosmetics (muzzle flash, impacts, sounds) | Each peer | Local reaction to synced facts |

## Build order (one small PR each, tests in every PR)

1. **Players in one match** (done, PR #73): `Net.host/join/leave`, `PlayerSpawner`,
   player sync, dedicated server runs a match, `--host` and `--join=addr:port`
   on the command line. Test: a real headless server plus two clients see two
   players.
2. **Zombies on clients** (done): `ZombieSync` replicates spawned zombies; clients run no AI.
3. **Shooting** (done): owners trace locally and claim hits; `HitClaims` checks
   living sender/target, weapon range, damage and per-player/weapon claim rate
   before applying normal server damage, kills, points and XP. Points sync to
   the owner. Hit markers are immediate; kill markers follow synced DEAD
   within 0.5 s of the owner's last hit. One unreliable cosmetic packet per
   shot relays muzzle origin and pellet endpoints through the server.
4. **Player health and death — done:** server health snapshots, 30 s bleed-out,
   sidearm crawl, 3 s revives within 1.5 m (50 points), teammate spectating,
   next-round pistol respawns, and shared results when the connected squad is down.
5. **Run end and saves (done):** owner-only
   reliable final XP grants bank through `bank_run_xp` into the client's own
   character file. Live owner XP snapshots survive a mid-run disconnect; the
   dedicated server saves no character. Hello checks protocol and the cached
   hash of sorted Content ids before spawning, with version/content/full reasons.
   The server's LootService rolls personal guns/gear using the accepted hello level,
   match RNG and current round, then sends each drop only to its owner. Each local
   Pack banks through Inventory into that client's stash at every run exit,
   including death and disconnect; overflow is logged and shown in results.
   Drops expire after 60 seconds and never replicate to another player.
6. **Menu (done):** Play solo, Host and play with a port field (default 7777),
   and Join with an address field (port optional). Settings remembers the last
   address and port. Joining shows the target and Cancel, with a 6-second
   timeout; one themed dialog explains invalid addresses, unreachable servers,
   occupied ports, full servers, version/content mismatches and disconnections.
   Clients distinguish a host ending the match from a lost connection.
   Menu buttons and fields support keyboard and gamepad focus. Server browser
   and LAN discovery come with P8.

7. **Interactions (done, plan `docs/plans/coop-interactions.md`, PRs #182,
   #183, #185):** one request path (`InteractionSync.request()` →
   `request_interact`); the server checks a living, standing sender, match not
   over, a path under the `Level`, reach + 2 m, one request per 0.1 s and the
   type's gun facts, then runs the same `interact()` as solo. Doors, power,
   barrier planks, Med Dispenser sales, Specimen Vault state and spot, and exfil
   open/hold reach every client; late joiners get one snapshot. Bought guns,
   ammo and Reforges reach the buyer as grants that name the gun they are for.

8. **Round state and power-ups (done, plan `docs/plans/coop-round-state-power-ups.md`,
   PRs #227 and this one):** the server relays round start, end and intermission
   to every client as the same `Events`; late joiners ask once for phase, round
   and time left. Clients never run the round loop. Power-up drops spawn through
   a `MultiplayerSpawner` under the level (late joiners get the age); only the
   server watches touches, picks the collector and frees the pickup. Resupply
   and ammo packs run `PowerUp.apply_effect()` on the PC that owns the guns.
   Protocol 10.

After step 8, P7 finishes with `docs/plans/coop-full-match.md` (F-47): co-op
soak, pause, squad cards, the hub and deploy flow, then a 4-player play-test to
round 20 (the P7 exit test).

## Running it locally

```bash
# Dedicated server on port 7777
godot --headless --path . res://systems/net/dedicated_server.tscn -- --port=7777
# A client that joins it (or start the game and pass the same argument)
godot --path . -- --join=127.0.0.1:7777
# Host and play (listen server)
godot --path . -- --host
```
