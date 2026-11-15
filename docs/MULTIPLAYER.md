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
  position, body yaw and head pitch from the owner to everyone.
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
| Points, wall buys, machines, doors | Server | Client sends a request RPC; server runs the same `Economy.try_spend()` |
| Waves, round number, power-ups | Server | Synced to all |
| Run XP and loot rolls | Server (`ProgressionService`) | Grant RPC to the owning client, which saves it |
| Cosmetics (muzzle flash, impacts, sounds) | Each peer | Local reaction to synced facts |

## Build order (one small PR each, tests in every PR)

1. **Players in one match** (done, PR #73): `Net.host/join/leave`, `PlayerSpawner`,
   player sync, dedicated server runs a match, `--host` and `--join=addr:port`
   on the command line. Test: a real headless server plus two clients see two
   players.
2. **Zombies on clients** (done): `ZombieSync` replicates spawned zombies; clients run no AI.
3. **Shooting:** hit claims to the server, damage, kills, points per player.
4. **Player health and death — done:** server health snapshots, 30 s bleed-out,
   sidearm crawl, 3 s revives within 1.5 m (50 points), teammate spectating,
   next-round pistol respawns, and shared results when the connected squad is down.
5. **Run end and saves:** XP and loot grants reach each client's own character
   file; version check on join (`Build.PROTOCOL_VERSION`).
6. **Menu:** Host and play, direct connect field, plain-word errors (full,
   wrong version). Server browser and LAN discovery come with P8.

After step 6, P7 continues with machines, doors and power-ups in co-op, then
a 4-player play-test to round 20 (the P7 exit test).

## Running it locally

```bash
# Dedicated server on port 7777
godot --headless --path . res://systems/net/dedicated_server.tscn -- --port=7777
# A client that joins it (or start the game and pass the same argument)
godot --path . -- --join=127.0.0.1:7777
# Host and play (listen server)
godot --path . -- --host
```
