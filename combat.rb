require './user'

require './asynchronous_processor'

class Combat < AsynchronousProcessorBase
  
  def initialize(game, room, *entities)
    super game

    @room = room
    @room.combat = self
    
    @entities = {}
    [entities].flatten.each_slice(2){|entity, target|
      @entities[entity] = target # no target to start with
    }
  end
  
  
  def set_target(entity, target)
    @entities[entity] = target
    self.game.get_users(in_room: entity.room, not_user: entity).send "#{entity.name} set target to #{target.name}"
    entity.send "You are now targetting #{target.name}"
  end
  
  def add_entity(entity, target)
    if @entities.key? entity
      # already in fight
    else
      @entities[entity] = target
    end
  end
  
  
  def remove_entity(entity)
    if !@entities.key? entity
      @entities.remove entity
    else
      # not in fight - probably no big deal
    end
  end
  
  
  def _run
    puts @entities
    puts @entities.size
    @entities.each{|entity, target|
      puts "Handling #{entity} attack phase in room #{entity.room}"
      results = entity.attack target
      @game.get_users(in_room: entity.room, not_user: entity).send "#{entity.name} attacks #{target.name} for #{results[:damage]} damage, #{target.hp} hp left"
      entity.send "You attack #{target.name} for #{results[:damage]} damage, #{target.hp} hp left"
    }
    @entities.reject!(&:dead?)
    
  end
  
  
  
end