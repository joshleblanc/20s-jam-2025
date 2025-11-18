module Effects
  def screen_shake(strength, duration)
    args.state.entities << {
      screen_shake: {
        strength: strength,
        duration: duration,
        offset_x: 0,
        offset_y: 0,
        initial_duration: duration
      }
    }
  end

  def process_screen_shake
    ids_to_remove = []
    offset_x = 0
    offset_y = 0

    args.state.entities.each_entity(:screen_shake) do |id, shake|
      if shake.duration > 0
        progress = shake.duration / shake.initial_duration.to_f
        intensity = shake.strength * progress
        shake.offset_x = (rand * 2 - 1) * intensity
        shake.offset_y = (rand * 2 - 1) * intensity
        shake.duration -= 1

      else
        ids_to_remove << id
      end
    end

    args.state.entities.destroy(*ids_to_remove) unless ids_to_remove.empty?
  end
end
