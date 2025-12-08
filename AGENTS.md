# AGENTS.md - AI Agent Guidelines for 20s-jam-2025

## Project Overview

A **DragonRuby GTK** roguelike dungeon crawler for a 20-second game jam. Players have 20 seconds to explore rooms, collect treasure, avoid traps, and fight enemies before time runs out.

## Running the Game

```bash
# From parent directory (where dragonruby executable lives)
../dragonruby 20s-jam-2025

# Or use the run script (Linux, sets SDL_VIDEODRIVER=x11)
./run
```

DragonRuby is a commercial engine - the executable must be in the parent directory. **No build step** - DragonRuby hot-reloads Ruby files on save.

## Code Organization

```
app/
├── main.rb           # Entry point - tick function, ECS world init
├── game.rb           # Main Game class - tick loop, rendering, all game logic
├── entity_manager.rb # Entity spawn helpers (spawn_player, spawn_wall, etc.)
├── effects.rb        # Visual effects (screen shake)
joshleblanc/drecs/
└── drecs.rb          # Drecs ECS library (external dependency)
errors/
├── last.txt          # Last runtime exception (DragonRuby auto-generates)
└── readme.txt        # Instructions for error reporting
```

## Architecture: Entity-Component-System (ECS)

Uses **Drecs** library - an archetype-based ECS with hash components.

### World Access

```ruby
args.state.entities  # The Drecs::World instance
```

### Creating Entities

```ruby
args.state.entities << {
  position: { x: 0, y: 0 },
  type: :player,
  char: "@",
  health: { amt: 3 }
}
```

### Querying Entities

```ruby
# Iterate all entities with components
args.state.entities.each_entity(:position, :health) do |id, pos, health|
  pos.x += 1
  health.amt -= 1
end

# Get first match (returns array: [id, comp1, comp2, ...])
player_id, _, pos, health = args.state.entities.first_entity(:player, :position, :health)

# Check component existence
args.state.entities.has_component?(id, :revealed)

# Get single component
health = args.state.entities.get_component(id, :health)
```

### Modifying Entities

```ruby
# Add component
args.state.entities.add_component(id, :triggered, true)

# Destroy (supports multiple IDs)
args.state.entities.destroy(id)
args.state.entities.destroy(*ids_array)
```

### Components Reference

| Component | Structure | Purpose |
|-----------|-----------|---------|
| `:position` | `{ x: Int, y: Int }` | Grid position |
| `:last_position` | `{ x: Int, y: Int }` | Previous position (collision rollback) |
| `:health` | `{ amt: Int }` | Health points |
| `:score` | `{ amt: Int }` | Player score |
| `:type` | Symbol | Entity type (`:player`, `:wall`, etc.) |
| `:char` | String | ASCII render character |
| `:inventory` | Array | Collected items as symbols |
| `:revealed` | Boolean | Fog of war visibility |
| `:triggered` | Boolean | Trap triggered state |
| `:timer` | `{ time_remaining: Int }` | Game countdown |
| `:screen_shake` | `{ strength:, duration:, offset_x:, offset_y:, initial_duration: }` | Shake effect |
| `:player` | Boolean | Player marker tag |
| `:slime`, `:bat`, `:goblin` | Boolean | Enemy type markers |
| `:log` | `{ messages: Array }` | Game message log |
| `:position_changed` | Boolean | Input event marker |
| `:state_change` | `{ to: Symbol }` | State transition marker |

### Entity Types

| Char | Type | Description |
|------|------|-------------|
| `@` | `:player` | Player (has health, score, inventory) |
| `#` | `:wall` | Blocks movement |
| `.` | `:floor` | Walkable |
| `k` | `:key` | Collectible key |
| `t` | `:treasure` | +1 score |
| `T` | `:trap` | Hidden, damages on contact |
| `S` | `:spike` | Visible hazard |
| `>` | `:exit` | Next level |
| `s` | `:slime` | Slow enemy (moves every 4 steps) |
| `b` | `:bat` | Fast diagonal enemy (every step) |
| `g` | `:goblin` | Medium cardinal enemy (every 2 steps) |
| `p` | `:potion` | Health pickup |

## Game Loop

`Game#tick` in `app/game.rb:70-89`:

```ruby
def tick
  start_game if args.state.tick_count == 0
  process_timer          # Countdown (real-time)
  handle_input           # Player movement
  process_enemy_ai       # Enemy movement (step-based)
  process_hit            # Collisions, pickups, combat
  reveal_tiles           # Fog of war
  render_static_map_stuff
  render_timer
  handle_state_change
  process_screen_shake
  render_target          # Draw :world to screen
  render_health
  render_inventory
  render_score
  render_log
end
```

## DragonRuby Patterns

### attr_gtk Macro

Provides access to engine objects:
- `args.state` - Persistent state across ticks
- `args.inputs` - Input (`left_right`, `up_down` return -1/0/1)
- `args.outputs` - Render primitives
- `args.gtk` - Engine utilities

### Rendering

```ruby
# Render to named target (used for screen shake offset)
args.outputs[:world].labels << { x:, y:, text:, size_enum:, r:, g:, b:, alignment_enum: }
args.outputs[:world].sprites << { x:, y:, w:, h:, path: }

# Draw target to screen
args.outputs.sprites << { x: 0, y: 0, w: 1280, h: 720, path: :world }

# Debug (top-left)
args.outputs.debug << "text"
```

### Coordinates

- Resolution: 1280x720
- Y-axis: 0 at bottom, increases upward
- Helpers: `100.from_top`, `300.from_right`

## Room System

ASCII art in `ROOMS` array (`app/game.rb:15-51`):

```ruby
ROOMS = [
  [
    "################",
    "#....s......t..#",
    "#..@...........#",
    "#.......k....>.#",
    "#....T.........#",
    "################",
  ],
  # ...
]
```

`spawn_map(room)` parses and creates entities. Legend comment at `game.rb:1-13`.

## Module Organization

`Game` class uses mixins:
- `include EntityManager` - `spawn_*` methods
- `include Effects` - `screen_shake`, `process_screen_shake`

### EntityManager Pattern

```ruby
def spawn_entity(x, y, char, what, **extra)
  args.state.entities << {
    position: { x: x, y: y },
    type: what,
    char: char,
    **extra
  }
end

def spawn_player(x, y)
  spawn_entity(x, y, "@", :player, {
    player: true,
    last_position: { x: x, y: y },
    health: { amt: 3 },
    score: { amt: 0 },
    inventory: []
  })
end
```

## Enemy AI

Step-based (triggers on player movement, not real-time):

```ruby
ENEMY_MOVE_INTERVAL = { bat: 1, goblin: 2, slime: 4 }
BAT_DELTAS = [[1,1], [1,-1], [-1,1], [-1,-1]]      # Diagonal
GOBLIN_DELTAS = [[1,0], [-1,0], [0,1], [0,-1]]    # Cardinal
SLIME_DELTAS = GOBLIN_DELTAS + BAT_DELTAS         # Both
```

## Combat

- Player moves into enemy → damage player, damage enemy, bounce player back
- Player steps on trap → damage, trap becomes visible
- Enemy health reaches 0 → destroyed, +1 score

## State Variables

```ruby
args.state.entities               # ECS World
args.state.game                   # Game instance
args.state.player_step_count      # Enemy AI timing
args.state.last_enemy_step_processed
```

## Common Patterns

### Guard for Missing Player

```ruby
player_id, _, pos, health = args.state.entities.first_entity(:player, :position, :health)
return unless player_id
```

### Deferred Destruction

```ruby
ids_to_destroy = []
args.state.entities.each_entity(:health) do |id, health|
  ids_to_destroy << id if health.amt <= 0
end
args.state.entities.destroy(*ids_to_destroy) unless ids_to_destroy.empty?
```

### Event Entities

Single-tick markers for coordination:

```ruby
# Signal
args.state.entities << { position_changed: true }

# Check
marker = args.state.entities.first_entity(:position_changed)
if marker
  # handle...
  args.state.entities.destroy(marker.first)
end
```

## Debugging

- `args.outputs.debug << "text"` - Prints to screen
- `errors/last.txt` - Contains last exception with backtrace
- DragonRuby console shows errors in real-time

## Gotchas

1. **Don't modify entities during iteration** - Collect IDs, destroy/modify after loop completes.

2. **first_entity returns array** - Use destructuring: `id, _, pos = args.state.entities.first_entity(:player, :position)`

3. **Components are symbols** - `:position` not `Position`. Data is plain hashes.

4. **Hot reload persists state** - `args.state` survives reload. Use `tick_count == 0` for init.

5. **Y-axis inverted** - Room row 0 is visual top, but DragonRuby Y=0 is bottom.

6. **Timer is real-time, AI is step-based** - Timer decrements every 60 ticks. Enemies move on player steps.

7. **Render order** - Later calls draw on top.

8. **Nil errors** - Check `errors/last.txt` for backtrace when entity queries return nil.

## Adding Features

### New Entity Type

1. Add char to legend comment (`game.rb:1-13`)
2. Add `spawn_*` in `entity_manager.rb`
3. Add case in `spawn_map` (`game.rb:443-461`)
4. Add behavior in `process_hit` or new method

### New Component

Just use it - Drecs creates archetypes dynamically:

```ruby
args.state.entities << { new_component: { data: "value" } }
```

### New Effect

1. Add create method to `Effects` module
2. Add `process_*` method
3. Call process method in `Game#tick`

## Testing

No automated tests. Run game and play to verify changes.
