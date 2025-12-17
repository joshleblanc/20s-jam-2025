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
    "#p...s......t..#",
    "#..@...........#",
    "#.......k....>.#",
    "#....T.........#",
    "################",
  ],
  [
    "################",
    "#@.....p.......#",
    "#######.########",
    "#t...s...s...k.#",
    "#######D########",
    "#.............>#",
    "################",
  ],
  [
    "################",
    "#@..s.......s..#",
    "#...T.......T..#",
    "#......k.......#",
    "#...T.......T..#",
    "#...s...p...s.>#",
    "################",
  ],
  [
    "################",
    "#@.#......p..t.#",
    "#.s..k.#.#####.#",
    "#..#.........#.#",
    "####.#######.#.#",
    "#>.D.........#.#",
    "################",
  ],
  [
    "################",
    "#@....D....t...#",
    "#.####.#######.#",
    "#....#....p....#",
    "#.k..#..s....>.#",
    "#....########..#",
    "################",
  ],
  [
    "################",
    "#@....s....p...#",
    "#..######.###..#",
    "#..k..D...t..>.#",
    "#..######.###..#",
    "################",
  ],
  [
    "################",
    "#@..g....#....>#",
    "#.####...#..T..#",
    "#..p..#..D..k..#",
    "#..b..#..####..#",
    "#.....#....t...#",
    "################",
  ],
  [
    "################",
    "#@.....S...p...#",
    "#.######.#####.#",
    "#..k..D.....t..#",
    "#.######.#####.#",
    "#.............>#",
    "################",
  ],
  [
    "################",
    "#@....s..g..b..#",
    "#.....T....p...#",
    "#..t....D...k..#",
    "#.............>#",
    "################",
  ],
  [
    "################",
    "#@..####...p...#",
    "#...#..D..####.#",
    "#.k.#......#...#",
    "#...####..#..t.#",
    "#.....>...#....#",
    "################",
  ]
]

class Game
  ENTITY_W = 40
  ENTITY_H = 40

  PALETTE = {
    bg: { r: 10, g: 12, b: 18 }.freeze,
    panel: { r: 18, g: 22, b: 34 }.freeze,
    panel_edge: { r: 40, g: 52, b: 90 }.freeze,
    text: { r: 236, g: 240, b: 255 }.freeze,
    muted: { r: 150, g: 160, b: 190 }.freeze,
    danger: { r: 255, g: 80, b: 92 }.freeze,
    gold: { r: 255, g: 200, b: 70 }.freeze,
    fog: { r: 6, g: 8, b: 12 }.freeze,
    floor: { r: 24, g: 28, b: 40 }.freeze,
    wall: { r: 70, g: 78, b: 100 }.freeze,
    accent: { r: 120, g: 160, b: 255 }.freeze
  }.freeze

  ENTITY_DRAW_PRIORITY = {
    floor: 0,
    wall: 1,
    door: 2,
    trap: 2,
    spike: 2,
    key: 3,
    treasure: 3,
    exit: 3,
    slime: 4,
    bat: 4,
    goblin: 4,
    player: 10
  }.freeze
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
    init_menu if args.state.tick_count == 0

    case args.state.game_state
    when :menu
      tick_menu
    when :game_over
      tick_game_over
    else
      tick_game
    end
  end

  def init_menu
    args.state.game_state = :menu
    args.state.highscores ||= []
    args.state.last_score = nil
  end

  def tick_menu
    render_menu
    handle_menu_input
  end

  def render_menu
    args.outputs.solids << {
      x: 0, y: 0, w: 1280, h: 720,
      **PALETTE[:bg]
    }

    render_panel(220, 140, 840, 440, target: :screen)

    args.outputs.labels << {
      x: 640, y: 520,
      text: "DUNGEON CRAWLER",
      size_enum: 10,
      alignment_enum: 1,
      **PALETTE[:text]
    }

    # Start button
    start_btn = { x: 540, y: 350, w: 200, h: 50 }
    args.outputs.solids << start_btn.merge(**PALETTE[:panel_edge], a: 180)
    args.outputs.borders << start_btn.merge(**PALETTE[:accent], a: 220)
    args.outputs.labels << {
      x: 640, y: 385,
      text: "START",
      size_enum: 4,
      alignment_enum: 1,
      **PALETTE[:text]
    }

    # Highscores
    args.outputs.labels << {
      x: 640, y: 292,
      text: "HIGH SCORES",
      size_enum: 4,
      alignment_enum: 1,
      **PALETTE[:gold]
    }

    top_scores = args.state.highscores.sort.reverse.take(5)
    top_scores.each_with_index do |score, i|
      args.outputs.labels << {
        x: 640, y: 240 - (i * 30),
        text: "#{i + 1}. #{score}",
        size_enum: 2,
        alignment_enum: 1,
        **PALETTE[:text]
      }
    end

    if top_scores.empty?
      args.outputs.labels << {
        x: 640, y: 240,
        text: "No scores yet",
        size_enum: 2,
        alignment_enum: 1,
        **PALETTE[:muted]
      }
    end
  end

  def handle_menu_input
    if args.inputs.keyboard.key_down.enter || args.inputs.keyboard.key_down.space
      start_game
      return
    end

    if args.inputs.mouse.click
      mouse = args.inputs.mouse
      start_btn = { x: 540, y: 350, w: 200, h: 50 }
      if mouse.x >= start_btn[:x] && mouse.x <= start_btn[:x] + start_btn[:w] &&
         mouse.y >= start_btn[:y] && mouse.y <= start_btn[:y] + start_btn[:h]
        start_game
      end
    end
  end

  def tick_game
    process_timer

    handle_input
    process_enemy_ai
    process_hit
    reveal_tiles
    process_visual_fx
    render_game_background
    render_map
    render_timer

    handle_state_change

    process_screen_shake
    render_target
    render_health
    render_inventory
    render_score
    render_log
  end

  def process_visual_fx
    if args.state.damage_flash_frames
      args.state.damage_flash_frames -= 1
      args.state.damage_flash_frames = nil if args.state.damage_flash_frames <= 0
    end
  end

  def render_game_background
    args.outputs[:world].solids << {
      x: 0, y: 0, w: 1280, h: 720,
      **PALETTE[:bg]
    }
  end

  def map_origin
    map_w = args.state.map_w || 16
    map_h = args.state.map_h || 8

    pad = 28
    map_px_w = map_w * ENTITY_W
    map_px_h = map_h * ENTITY_H

    x = pad
    y = (720 - map_px_h) / 2

    { x: x, y: y, w: map_px_w, h: map_px_h, map_w: map_w, map_h: map_h }
  end

  def grid_to_px_x(grid_x)
    map_origin[:x] + (grid_x * ENTITY_W)
  end

  def grid_to_px_y(grid_y)
    o = map_origin
    o[:y] + ((o[:map_h] - 1 - grid_y) * ENTITY_H)
  end

  def render_panel(x, y, w, h, target: :world)
    outputs = target == :screen ? args.outputs : args.outputs[target]
    outputs.solids << { x: x, y: y, w: w, h: h, **PALETTE[:panel] }
    outputs.borders << { x: x, y: y, w: w, h: h, **PALETTE[:panel_edge], a: 200 }
  end

  def render_map
    o = map_origin
    render_panel(o[:x] - 12, o[:y] - 12, o[:w] + 24, o[:h] + 24)

    revealed = {}
    args.state.entities.each_entity(:position, :revealed) do |_, pos, _|
      revealed[[pos.x, pos.y]] = true
    end

    cells = {}
    args.state.entities.each_entity(:position, :char, :type) do |id, pos, char, type|
      next if char == "T" && !args.state.entities.has_component?(id, :triggered)
      key = [pos.x, pos.y]

      prio = ENTITY_DRAW_PRIORITY[type] || 0
      existing = cells[key]
      if existing.nil? || prio >= existing[:prio]
        cells[key] = { id: id, char: char, type: type, prio: prio }
      end
    end

    (0...o[:map_w]).each do |gx|
      (0...o[:map_h]).each do |gy|
        x = grid_to_px_x(gx)
        y = grid_to_px_y(gy)

        if revealed[[gx, gy]]
          base = PALETTE[:floor]
          if (cells[[gx, gy]] && (cells[[gx, gy]][:type] == :wall || cells[[gx, gy]][:type] == :door))
            base = PALETTE[:wall]
          end
          args.outputs[:world].solids << { x: x, y: y, w: ENTITY_W, h: ENTITY_H, **base }
          args.outputs[:world].solids << { x: x, y: y, w: ENTITY_W, h: ENTITY_H, r: 0, g: 0, b: 0, a: 25 }
        else
          args.outputs[:world].solids << { x: x, y: y, w: ENTITY_W, h: ENTITY_H, **PALETTE[:fog] }
          args.outputs[:world].solids << { x: x, y: y, w: ENTITY_W, h: ENTITY_H, r: 0, g: 0, b: 0, a: 90 }
        end
      end
    end

    player_id, _, player_pos = args.state.entities.first_entity(:player, :position)
    player_bob_y = 0
    if player_id
      dt = args.state.last_player_move_tick ? (args.state.tick_count - args.state.last_player_move_tick) : 999
      if dt < 8
        player_bob_y = Math.sin(dt.fdiv(8) * Math::PI) * 8
        args.outputs[:world].solids << {
          x: grid_to_px_x(player_pos.x),
          y: grid_to_px_y(player_pos.y),
          w: ENTITY_W,
          h: ENTITY_H,
          **PALETTE[:accent],
          a: 30
        }
      end
    end

    cells.each do |(gx, gy), cell|
      next unless revealed[[gx, gy]]
      next if cell[:type] == :floor || cell[:type] == :wall
      x = grid_to_px_x(gx)
      y = grid_to_px_y(gy)

      r, g, b = PALETTE[:text].values_at(:r, :g, :b)
      case cell[:type]
      when :player
        r, g, b = PALETTE[:accent].values_at(:r, :g, :b)
      when :treasure
        r, g, b = PALETTE[:gold].values_at(:r, :g, :b)
      when :key
        r, g, b = 200, 220, 255
      when :exit
        r, g, b = 140, 255, 170
      when :slime
        r, g, b = 120, 255, 150
      when :bat
        r, g, b = 220, 180, 255
      when :goblin
        r, g, b = 255, 170, 120
      when :spike
        r, g, b = 210, 220, 235
      when :door
        r, g, b = 210, 170, 95
      when :potion
        r, g, b = 255, 140, 180
      when :trap
        r, g, b = PALETTE[:danger].values_at(:r, :g, :b)
      end

      if args.state.damage_flash_frames && cell[:type] == :player
        r, g, b = PALETTE[:danger].values_at(:r, :g, :b)
      end

      wobble = Math.sin((args.state.tick_count + (cell[:id] * 7)).fdiv(12)) * 2
      extra_y = 0
      if cell[:type] == :player
        extra_y = player_bob_y
      elsif enemy_type?(cell[:type])
        extra_y = wobble
      end

      args.outputs[:world].labels << {
        x: x + (ENTITY_W / 2),
        y: y + (ENTITY_H / 2) + 2 + extra_y,
        text: cell[:char],
        alignment_enum: 1,
        vertical_alignment_enum: 1,
        size_enum: 3,
        r: r, g: g, b: b
      }
    end
  end

  def process_hit
    player, _, pos_a, last_pos = args.state.entities.first_entity(:player, :position, :last_position)
    return unless player

    args.state.entities.each_entity(:position, :char, :type) do |id, pos_b, char, type|
      next if id == player
      next unless pos_b.x == pos_a.x && pos_b.y == pos_a.y

      if char == "T" && !args.state.entities.has_component?(id, :triggered)
        args.state.entities.defer { _1.add_component(id, :triggered, true) }
        log_message("Triggered a trap!")
        damage_player(1)
      elsif enemy_type?(type)
        health = args.state.entities.get_component(id, :health)
        next unless health
        if !damage_player(1) && damage_enemy(id, health)
          args.state.entities.defer { _1.destroy(id) }
        end
      elsif char == "k"
        _, inventory = args.state.entities.first_entity(:inventory)
        args.state.entities.defer { _1.destroy(id) }
        inventory << :key
        log_message("Picked up a key.")
      elsif char == "t"
        _, score = args.state.entities.first_entity(:score)
        score.amt += 1
        args.state.entities.defer { _1.destroy(id) }
        log_message("Found treasure!")
      elsif char == ">"
        log_message("Found the exit!")
        next_level
        return
      elsif char == "P"
        log_message("Found a potion!")
        health = args.state.entities.get_component(player, :health)
        next unless health
        health.amt = 3
        args.state.entities.defer { _1.destroy(id) }
      end
    end
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
    args.state.damage_flash_frames = 10
    pos.x = last_pos.x
    pos.y = last_pos.y

    if health.amt <= 0
      log_message("You died!")
      _, score = args.state.entities.first_entity(:score)
      final_score = score ? score.amt : 0
      end_game(final_score)
      return true
    end

    false
  end

  def render_health
    id, _, health = args.state.entities.first_entity(:player, :health)
    return unless id

    x = 24
    y = 720 - 24
    render_panel(x - 12, y - 46, 260, 44)
    args.outputs[:world].labels << {
      x: x,
      y: y - 18,
      text: "HP  #{health.amt}",
      size_enum: 3,
      **PALETTE[:danger],
      alignment_enum: 0,
      vertical_alignment_enum: 2
    }
  end

  def render_score
    id, score = args.state.entities.first_entity(:score)
    return unless id

    text = "SCORE  #{score.amt}"
    tw, _th = args.gtk.calcstringbox(text, 3)
    x = 1280 - 24 - tw - 24
    y = 720 - 24
    render_panel(x - 12, y - 46, tw + 48, 44)
    args.outputs[:world].labels << {
      x: x,
      y: y - 18,
      text: text,
      size_enum: 3,
      **PALETTE[:gold],
      alignment_enum: 0,
      vertical_alignment_enum: 2
    }
  end

  def render_inventory
    player, inventory = args.state.entities.first_entity(:inventory)
    return unless player

    x = 24
    y = 720 - 80
    render_panel(x - 12, y - 46, 360, 44)
    text = if inventory.empty?
             "INV  (empty)"
           else
             "INV  " + inventory.map { |i| i.to_s.capitalize }.join("  ")
           end
    args.outputs[:world].labels << {
      x: x,
      y: y - 18,
      text: text,
      size_enum: 2,
      **PALETTE[:text],
      alignment_enum: 0,
      vertical_alignment_enum: 2
    }
  end

  def render_log
    _, log = args.state.entities.first_entity(:log)
    return unless log

    x = 1280 - 24 - 360
    y = 24
    w = 360
    h = 720 - 24 - 24

    render_panel(x, y, w, h)
    args.outputs[:world].labels << {
      x: x + 16,
      y: y + h - 18,
      text: "LOG",
      size_enum: 2,
      **PALETTE[:muted],
      alignment_enum: 0,
      vertical_alignment_enum: 2
    }

    max = 22
    log.messages.last(max).reverse.each_with_index do |msg, i|
      args.outputs[:world].labels << {
        x: x + 16,
        y: y + h - 52 - (i * 24),
        text: msg,
        size_enum: 1,
        **PALETTE[:text],
        alignment_enum: 0,
        vertical_alignment_enum: 2
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
     x = shake.offset_x.to_i
     y = shake.offset_y.to_i
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
        args.state.entities.defer { _1.add_component(id, :revealed, true) }
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
      time_text = timer.time_remaining.to_s
      tw, _th = args.gtk.calcstringbox(time_text, 6)
      x = (1280 / 2) - (tw / 2)
      y = 720 - 24

      render_panel(x - 18, y - 62, tw + 36, 56)
      color = timer.time_remaining <= 5 ? PALETTE[:danger] : PALETTE[:text]
      args.outputs[:world].labels << {
        x: 1280 / 2,
        y: y - 26,
        alignment_enum: 1,
        vertical_alignment_enum: 2,
        size_enum: 6,
        text: time_text,
        **color
      }
    end
  end


  def process_timer
    return unless args.state.tick_count % 60 == 0
    args.state.entities.each_entity(:timer) do |id, timer|
      timer.time_remaining -= 1
      if timer.time_remaining == 0
        log_message("Time's up!")
        args.state.entities << {
          state_change: { to: :end_game }
        }
      end
    end
  end

  def handle_state_change
    args.state.entities.each_entity(:state_change) do |id, state_change|
      args.state.entities.defer { _1.destroy(id) }
      if state_change.to == :end_game
        _, score = args.state.entities.first_entity(:score)
        final_score = score ? score.amt : 0
        end_game(final_score)
      end
    end
  end

  def start_game
    args.state.game_state = :playing
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

  def end_game(final_score)
    args.state.highscores ||= []
    args.state.highscores << final_score
    args.state.last_score = final_score
    args.state.game_state = :game_over
  end

  def tick_game_over
    render_game_over
    handle_game_over_input
  end

  def render_game_over
    args.outputs.solids << {
      x: 0, y: 0, w: 1280, h: 720,
      **PALETTE[:bg]
    }

    main_x = 24
    main_y = 150
    main_w = 840
    main_h = 420
    main_cx = main_x + (main_w / 2)
    render_panel(main_x, main_y, main_w, main_h, target: :screen)

    args.outputs.labels << {
      x: main_cx, y: 520,
      text: "GAME OVER",
      size_enum: 10,
      alignment_enum: 1,
      **PALETTE[:danger]
    }

    args.outputs.labels << {
      x: main_cx, y: 440,
      text: "Score: #{args.state.last_score}",
      size_enum: 6,
      alignment_enum: 1,
      **PALETTE[:text]
    }

    _, log = args.state.entities.first_entity(:log)
    if log
      log_x = 1280 - 24 - 360
      log_y = 24
      log_w = 360
      log_h = 720 - 24 - 24
      render_panel(log_x, log_y, log_w, log_h, target: :screen)
      args.outputs.labels << {
        x: log_x + 16,
        y: log_y + log_h - 18,
        text: "LOG",
        size_enum: 2,
        **PALETTE[:muted],
        alignment_enum: 0,
        vertical_alignment_enum: 2
      }

      max = 22
      log.messages.last(max).reverse.each_with_index do |msg, i|
        args.outputs.labels << {
          x: log_x + 16,
          y: log_y + log_h - 52 - (i * 24),
          text: msg,
          size_enum: 1,
          **PALETTE[:text],
          alignment_enum: 0,
          vertical_alignment_enum: 2
        }
      end
    end

    # Check if high score
    if args.state.highscores.sort.reverse.first == args.state.last_score
      args.outputs.labels << {
        x: main_cx, y: 370,
        text: "NEW HIGH SCORE!",
        size_enum: 4,
        alignment_enum: 1,
        **PALETTE[:gold]
      }
    end

    # Play Again button
    play_btn = { x: main_cx - 200, y: 250, w: 180, h: 50 }
    args.outputs.solids << play_btn.merge(**PALETTE[:panel_edge], a: 180)
    args.outputs.borders << play_btn.merge(**PALETTE[:accent], a: 220)
    args.outputs.labels << {
      x: play_btn[:x] + 90, y: 285,
      text: "PLAY AGAIN",
      size_enum: 3,
      alignment_enum: 1,
      **PALETTE[:text]
    }

    # Menu button
    menu_btn = { x: main_cx + 20, y: 250, w: 180, h: 50 }
    args.outputs.solids << menu_btn.merge(**PALETTE[:panel_edge], a: 180)
    args.outputs.borders << menu_btn.merge(**PALETTE[:accent], a: 220)
    args.outputs.labels << {
      x: menu_btn[:x] + 90, y: 285,
      text: "MENU",
      size_enum: 3,
      alignment_enum: 1,
      **PALETTE[:text]
    }
  end

  def handle_game_over_input
    if args.inputs.keyboard.key_down.enter || args.inputs.keyboard.key_down.space
      start_game
      return
    end

    if args.inputs.keyboard.key_down.escape
      args.state.game_state = :menu
      return
    end

    if args.inputs.mouse.click
      mouse = args.inputs.mouse

      play_btn = { x: 244, y: 250, w: 180, h: 50 }
      if mouse.x >= play_btn[:x] && mouse.x <= play_btn[:x] + play_btn[:w] &&
         mouse.y >= play_btn[:y] && mouse.y <= play_btn[:y] + play_btn[:h]
        start_game
        return
      end

      menu_btn = { x: 464, y: 250, w: 180, h: 50 }
      if mouse.x >= menu_btn[:x] && mouse.x <= menu_btn[:x] + menu_btn[:w] &&
         mouse.y >= menu_btn[:y] && mouse.y <= menu_btn[:y] + menu_btn[:h]
        args.state.game_state = :menu
      end
    end
  end

  def handle_input
    pos_changed = args.state.entities.first_entity(:position_changed)
    player, _, pos, last_pos = args.state.entities.first_entity(:player, :position, :last_position)

    x_change = args.inputs.left_right
    y_change = -args.inputs.up_down


    if (x_change != 0 || y_change != 0) && !pos_changed
      target_x = pos.x + x_change
      target_y = pos.y + y_change

      door_id = nil
      args.state.entities.each_entity(:position, :char) do |id, dpos, char|
        if char == "D" && dpos.x == target_x && dpos.y == target_y
          door_id = id
          break
        end
      end

      if door_id
        inventory = args.state.entities.get_component(player, :inventory)
        if inventory && inventory.include?(:key)
          inventory.delete_at(inventory.index(:key))
          args.state.entities.destroy(door_id)
          log_message("Unlocked a door.")
        end
      end

      return unless can_move?(target_x, target_y)

      last_pos.x = pos.x
      last_pos.y = pos.y
      pos.x += x_change
      pos.y += y_change
      args.state.last_player_move_tick = args.state.tick_count
      args.state.player_step_count ||= 0
      args.state.player_step_count += 1
      args.state.entities << {
        position_changed: true
      }

      dir_text = if x_change > 0 then "right"
                 elsif x_change < 0 then "left"
                 elsif y_change > 0 then "down"
                 elsif y_change < 0 then "up"
                 end
      log_message("Moved #{dir_text}") if dir_text
    elsif x_change == 0 && y_change == 0 && pos_changed
      args.state.entities.destroy(pos_changed.first)
    end
  end

  def can_move?(x, y)
    args.state.entities.each_entity(:position, :char) do |_, pos, char|
      if (char == "#" || char == "D") && pos.x == x && pos.y == y
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

    args.state.map_h = room.length
    args.state.map_w = room.first ? room.first.length : 0
    room.each_with_index do |row, y|
      row.chars.each_with_index do |char, x|
        spawn_floor(x, y)
        case char
        when "#" then spawn_wall(x, y)
        when "@" then spawn_player(x, y)
        when "D" then spawn_door(x, y)
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
