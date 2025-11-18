require "joshleblanc/drecs/drecs"
require "app/effects"
require "app/entity_manager"
require "app/game"

def tick(args)
  if args.state.tick_count == 0 
    args.state.entities = Drecs::World.new
    args.state.game = Game.new
  end

  args.state.game.args = args 
  args.state.game.tick
end


