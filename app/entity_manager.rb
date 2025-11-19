module EntityManager
  def spawn_entity(x, y,char, what, **extra)
    args.state.entities << {
      position: { x: x, y: y },
      type: what,
      char: char,
      **extra
    }
  end
  
  def spawn_player(x, y)
    spawn_entity(x, y, "@", :player, { player: true, last_position: { x: x, y: y }, health: { amt: 3 }, inventory: [] })
  end

  def spawn_wall(x, y)
    spawn_entity(x, y, "#", :wall)
  end

  def spawn_floor(x, y)
    spawn_entity(x, y, ".", :floor)
  end

  def spawn_key(x, y)
    spawn_entity(x, y, "k", :key)
  end

  def spawn_trap(x, y)
    spawn_entity(x, y, "T", :trap)
  end

  def spawn_treasure(x, y)
    spawn_entity(x, y, "t", :treasure)
  end

  def spawn_spike(x, y)
    spawn_entity(x, y, "S", :spike)
  end

  def spawn_potion(x, y)
    spawn_entity(x, y, "P", :potion)
  end

  def spawn_slime(x, y)
    spawn_entity(x, y, "s", :slime, { slime: true })
  end

  def spawn_goblin(x, y)
    spawn_entity(x, y, "g", :goblin, { goblin: true })
  end

  def spawn_bat(x,y)
    spawn_entity(x, y, "b", :bat, { bat:true })
  end

  def spawn_exit(x, y)
    spawn_entity(x, y, ">", :exit)
  end
end
