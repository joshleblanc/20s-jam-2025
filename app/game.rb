##
# T - Trap
# k - Key
# s - Slime
# b - Bat
# g - Goblin
# p - Potion
# S - Spike
# > - Exit
# t - Treasure
# # - Wall
# . - Floor
# @ - Player

ROOMS = [
  [
    "################",
    "#....s......t..#",
    "#..@...........#",
    "#.......k....>.#",
    "#....T.........#",
    "################",
  ],
  [
    "################",
    "#@.............#",
    "#######.########",
    "#t...s...s...k.#",
    "#######.########",
    "#.............>#",
    "################",
  ],
  [
    "################",
    "#@..s.......s..#",
    "#...T.......T..#",
    "#......k.......#",
    "#...T.......T..#",
    "#...s.......s.>#",
    "################",
  ],
  [
    "################",
    "#@.#.........t.#",
    "#.s..k.#.#####.#",
    "#..#.........#.#",
    "####.#######.#.#",
    "#>...........#.#",
    "################",
  ]
]

class Game
  ENTITY_W = 32
  ENTITY_H = 64
  ENEMY_MOVE_INTERVAL = {
    bat: 1,      # moves every player step
    goblin: 2,   # every other player step
    slime: 4     # very slow
  }.freeze
  BAT_DELTAS = [[1, 1], [1, -1], [-1, 1], [-1, -1]].freeze
  GOBLIN_DELTAS = [[1, 0], [-1, 0], [0, 1], [0, -1]].freeze
  SLIME_DELTAS = (GOBLIN_DELTAS + BAT_DELTAS).freeze

  include EntityManager
  include Effects

  attr_gtk

  def tick
    start_game if args.state.tick_count == 0
    process_timer

    handle_input
    process_enemy_ai
    process_hit
    reveal_tiles
    render_static_map_stuff
    render_timer

    handle_state_change

    process_screen_shake
    render_target
    render_health
    render_inventory
    render_score
    render_log
  end

  def process_hit
    player, _, pos_a, last_pos = args.state.entities.first_entity(:player, :position, :last_position)
    return unless player

    ids_to_destroy = []

    args.state.entities.each_entity(:position, :char, :type) do |id, pos_b, char, type|
      next if id == player
      next unless pos_b.x == pos_a.x && pos_b.y == pos_a.y

      if char == "T" && !args.state.entities.has_component?(id, :triggered)
        args.state.entities.add_component(id, :triggered, true)
        log_message("Triggered a trap!")
        damage_player(1)
      elsif enemy_type?(type)
        health = args.state.entities.get_component(id, :health)
        next unless health
        if !damage_player(1) && damage_enemy(id, health)
          ids_to_destroy << id
        end
      elsif char == "k"
        _, inventory = args.state.entities.first_entity(:inventory)
        args.state.entities.destroy(id)
        inventory << :key
        log_message("Picked up a key.")
      elsif char == "t"
        _, score = args.state.entities.first_entity(:score)
        score.amt += 1
        args.state.entities.destroy(id)
        log_message("Found treasure!")
      elsif char == ">"
        log_message("Found the exit!")
        next_level
        return
      end
    end

    args.state.entities.destroy(*ids_to_destroy) unless ids_to_destroy.empty?

  end

  def next_level
    player_id, _, health, score, inventory = args.state.entities.first_entity(:player, :health, :score, :inventory)

    saved_health = health.amt
    saved_score = score.amt
    saved_inventory = inventory.dup

    spawn_map(ROOMS.sample)
    log_message("Entered a new room.")

    new_player_id, _, new_health, new_score, new_inventory = args.state.entities.first_entity(:player, :health, :score, :inventory)

    if new_player_id
      new_health.amt = saved_health
      new_score.amt = saved_score
    end
  end

  def damage_player(amount)
    player, _, pos, last_pos, health = args.state.entities.first_entity(:player, :position, :last_position, :health)
    return unless player

    health.amt -= amount
    log_message("Took #{amount} damage!")
    screen_shake(2, 10)
    pos.x = last_pos.x
    pos.y = last_pos.y

    if health.amt <= 0
      log_message("You died!")
      spawn_map(ROOMS.sample)
      true
    end

    false
  end

  def render_health
    id, _, health = args.state.entities.first_entity(:player, :health)
    return unless id

    args.outputs[:world].labels << {
      x: 10,
      y: 710,
      text: "Health: #{health.amt}",
      size_enum: 2,
      r: 255,
      g: 0,
      b: 0,
      alignment_enum: 0,
      vertical_alignment_enum: 2
    }
  end

  def render_score
    id, score = args.state.entities.first_entity(:score)
    return unless id

    text = "Score: #{score.amt}"
    tw, th = args.gtk.calcstringbox(text, 2)
    args.outputs[:world].labels << {
      x: 640,
      y: 0.from_top - (th * 2),
      text: text,
      size_enum: 2,
      r: 0,
      g: 0,
      b: 0,
      alignment_enum: 0,
      vertical_alignment_enum: 2
    }
  end

  def render_inventory
    player, inventory = args.state.entities.first_entity(:inventory)
    return unless player

    inventory.each_with_index do |item, i|
      args.outputs[:world].labels << {
        x: 10 + (i * 100),
        y: 680,
        text: item.to_s.capitalize,
        size_enum: 2,
        r: 255,
        g: 255,
        b: 255,
        alignment_enum: 0,
        vertical_alignment_enum: 2
      }
    end
  end

  def render_log
    _, log = args.state.entities.first_entity(:log)
    return unless log

    x = 300.from_right
    y = 200

    # Show last 20 messages, reversed so newest is at top (below header)
    log.messages.last(20).reverse.each_with_index do |msg, i|
      args.outputs[:world].labels << {
        x: x,
        y: y - 25 - (i * 25),
        text: msg,
        size_enum: 0,
        r: 0, g: 0, b: 0,
        alignment_enum: 0
      }
    end
  end

  def log_message(text)
    _, log = args.state.entities.first_entity(:log)
    log.messages << text
  end

  def render_target
    _, shake = args.state.entities.first_entity(:screen_shake)
    x = 0
    y = 0
    if shake
     x = shake.offset_x
     y = shake.offset_y
    end
    args.outputs.sprites << {
      x: x, y: y, w: 1280, h: 720,
      path: :world
    }
  end

  def reveal_tiles
    _, _, pos_a = args.state.entities.first_entity(:player, :position)

    args.state.entities.each_entity(:position) do |id, pos_b|
      next if args.state.entities.has_component?(id, :revealed)

      if (pos_a.x - pos_b.x).abs < 2 && (pos_a.y - pos_b.y).abs < 2
        args.state.entities.add_component(id, :revealed, true)
      end
    end
  end

  def render_static_map_stuff
    args.state.entities.each_entity(:position, :char, :revealed) do |id, pos, char, revealed|
      next if char == "T" && !args.state.entities.has_component?(id, :triggered)
      args.outputs[:world].labels << {
        x: pos.x * ENTITY_W,
        y: pos.y * ENTITY_H,
        text: char,
        w: ENTITY_W,
        h: ENTITY_H,
        alignment_enum: 1,
        size_enum: 2,
        vertical_alignment_enum: 1
      }
    end
  end


  def render_timer
    args.state.entities.each_entity(:timer) do |_, timer|
      args.outputs.debug << timer.time_remaining.to_s
      tw,th = args.gtk.calcstringbox(timer.time_remaining.to_s, 4)

      args.outputs[:world].labels << {
        x: (1280 / 2) + (tw / 2),
        y: th.from_top,
        alignment_enum: 0,
        size_enum: 4,
        text: timer.time_remaining.to_s
      }
    end
  end


  def process_timer
    return unless args.state.tick_count % 60 == 0
    args.state.entities.each_entity(:timer) do |id, timer|
      timer.time_remaining -= 1
      if timer.time_remaining == 0
        args.state.entities << {
          state_change: { to: :end_game }
        }
      end
    end
  end

  def handle_state_change
    ids_to_remove = []
    args.state.entities.each_entity(:state_change) do |id, state_change|
      ids_to_remove << id
      # delete everything
    end
    args.state.entities.destroy *ids_to_remove
  end

  def start_game
    args.state.entities = Drecs::World.new
    args.state.entities << {
      timer: { time_remaining: 20 }
    }
    args.state.entities << {
      log: { messages: ["Welcome to the dungeon!"] }
    }
    args.state.player_step_count = 0
    args.state.last_enemy_step_processed = 0

    spawn_map(ROOMS.sample)
  end

  def handle_input
    pos_changed = args.state.entities.first_entity(:position_changed)

    args.outputs.debug << pos_changed.to_s
    player, _, pos, last_pos = args.state.entities.first_entity(:player, :position, :last_position)

    x_change = args.inputs.left_right
    y_change = args.inputs.up_down


    if (x_change != 0 || y_change != 0) && !pos_changed && can_move?(pos.x + x_change, pos.y + y_change)
      last_pos.x = pos.x
      last_pos.y = pos.y
      pos.x += x_change
      pos.y += y_change
      args.state.player_step_count ||= 0
      args.state.player_step_count += 1
      args.state.entities << {
        position_changed: true
      }

      dir_text = if x_change > 0 then "right"
                 elsif x_change < 0 then "left"
                 elsif y_change > 0 then "up"
                 elsif y_change < 0 then "down"
                 end
      log_message("Moved #{dir_text}") if dir_text
    elsif x_change == 0 && y_change == 0 && pos_changed
      args.state.entities.destroy(pos_changed.first)
    end
  end

  def can_move?(x, y)
    args.state.entities.each_entity(:position, :char) do |_, pos, char|
      if char == "#" && pos.x == x && pos.y == y
        return false
      end
    end
    true
  end

  def process_enemy_ai
    current_step = args.state.player_step_count || 0
    last_processed = args.state.last_enemy_step_processed || 0
    return if current_step == last_processed

    args.state.entities.each_entity(:position, :type, :health) do |id, pos, type, health|
      next if health.amt <= 0
      case type
      when :bat
        attempt_enemy_move(:bat, pos, BAT_DELTAS, current_step)
      when :goblin
        attempt_enemy_move(:goblin, pos, GOBLIN_DELTAS, current_step)
      when :slime
        attempt_enemy_move(:slime, pos, SLIME_DELTAS, current_step)
      end
    end

    args.state.last_enemy_step_processed = current_step
  end

  def attempt_enemy_move(type, pos, deltas, current_step)
    return unless enemy_ready_to_move?(type, current_step)
    deltas.shuffle.each do |dx, dy|
      new_x = pos.x + dx
      new_y = pos.y + dy
      next unless can_move?(new_x, new_y)

      pos.x = new_x
      pos.y = new_y
      break
    end
  end

  def enemy_ready_to_move?(type, current_step)
    interval = ENEMY_MOVE_INTERVAL[type] || 15
    interval > 0 && current_step % interval == 0
  end

  def enemy_type?(type)
    type == :bat || type == :goblin || type == :slime
  end

  def damage_enemy(enemy_id, health)
    health.amt -= 1
    if health.amt <= 0
      _, score = args.state.entities.first_entity(:score)
      score.amt += 1 if score
      log_message("Defeated an enemy!")
      return true
    end
    false
  end

  def spawn_map(room)
    to_delete = []
    args.state.entities.query(:position) do |ids, _|
      to_delete.concat(ids)
    end
    args.state.entities.destroy *to_delete
    room.each_with_index do |row, y|
      row.chars.each_with_index do |char, x|
        spawn_floor(x, y)
        case char
        when "#" then spawn_wall(x, y)
        when "@" then spawn_player(x, y)
        when "k" then spawn_key(x, y)
        when "T" then spawn_trap(x, y)
        when "t" then spawn_treasure(x, y)
        when "s" then spawn_slime(x, y)
        when "b" then spawn_bat(x, y)
        when "g" then spawn_goblin(x, y)
        when "k" then spawn_key(x, y)
        when "p" then spawn_potion(x, y)
        when "S" then spawn_spike(x, y)
        when ">" then spawn_exit(x, y)
        end
      end
    end
  end
end
