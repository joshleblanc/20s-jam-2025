ROOMS = [
  [
    "################",
    "#....s.........#",
    "#..@...........#",
    "#.......k....>.#",
    "#....T.........#",
    "################",
  ]
]

class Game 
  ENTITY_W = 32
  ENTITY_H = 64
  include EntityManager

  attr_gtk

  def tick
    start_game if args.state.tick_count == 0
    process_timer

    handle_input
    reveal_tiles
    render_static_map_stuff
    render_timer

    handle_state_change
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
    args.state.entities.each_entity(:position, :char, :revealed) do |_, pos, char, revealed|
      args.outputs.labels << {
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

      args.outputs.labels << { 
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
    args.state.entities << { 
      timer: { time_remaining: 20 }
    }

    spawn_map(ROOMS.sample)
  end

  def handle_input 
    pos_changed = args.state.entities.first_entity(:position_changed)

    args.outputs.debug << pos_changed.to_s
    _, _, pos = args.state.entities.first_entity(:player, :position) 

    x_change = args.inputs.left_right
    y_change = args.inputs.up_down


    if (x_change != 0 || y_change != 0) && !pos_changed && can_move?(pos.x + x_change, pos.y + y_change)
      pos.x += x_change
      pos.y += y_change
      args.state.entities << {
        position_changed: true
      }
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

  def spawn_map(room)
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
