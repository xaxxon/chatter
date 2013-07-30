require './user'

require './asynchronous_processor'

class Combat < AsynchronousProcessorBase
  
  attr_reader :room
  
  def initialize(game, room, *entities)
    super game

    @room = room
    
    @entities = {}
    [entities].flatten.each_slice(2){|entity, target|
      self.add_entity entity, target
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
      entity.combat = self
    end
  end
  
  
  def remove_entity(entity)
    if @entities.key? entity
      @entities.delete entity
    else
      # not in fight - probably no big deal
    end
  end
  
  
  def _run
    puts @entities
    puts @entities.size
    @entities.each{|entity, target|
      results = entity.attack target
      @room.send("#{entity.name} attacks #{target.name} for #{results[:damage]} damage, #{target.hp} hp left", not_user: entity)
      entity.send "You attack #{target.name} for #{results[:damage]} damage, #{target.hp} hp left"
    }
    
    @entities.keys.each{|entity|
      entity.update_status
    }

    monsters = self.monsters
    users = self.users
  
    if monsters.empty? and users.empty?
      return true
    elsif monsters.empty?
      self.send "You've won!\n"
      return true
    elsif users.empty?
      return true
    end
    
    # combat isn't over, so make sure everyone has a target
    @entities.each{|entity, target|
      # if this entities target is dead
      unless @entities[target]
        @entities[entity] = if entity.monster? then users.shuffle[0] else monsters.shuffle[0] end
      end
    }
        
    # combat is not complete
    return false    
        
  end
  
  def send(message, **params)
    Game.filter_users(self.users, **params).send message
  end
  
  def monsters
    @entities.keys.select{|entity| entity.monster?}
  end
  
  def users
    @entities.keys.reject{|entity| entity.monster?}
  end
  
end