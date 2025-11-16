class Game 
  attr_gtk

  def tick
    start_game if args.state.tick_count == 0
    process_timer

    render_timer

    handle_state_change
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
  end
end
