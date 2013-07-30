

class Entity
  
  attr_accessor :hp, :combat, :game, :room
  attr_reader :name
  
  def initialize(game, room, hp, weapon, name)
    @game = game
    @room = room
    @hp = hp
    @max_hp = hp  
    @weapon = weapon
    @name = name
  end
  
  
  def attack(target)
    target.hp -= @weapon.damage
    return {damage: @weapon.damage}
  end
  
  
  def dead?
    self.hp <= 0
  end



  def update_status
    if self.dead?
      
      @combat.remove_entity self
    
      # remove from room
      @room.remove_entity self
      
      @room.send "#{self.name} the #{self.type} is dead"
      
    end
  end
  
  
  def monster?
    return true;
  end


  # no-op for NPCs, otherwise it sends to user
  def send(data)
    
  end
  
  
  def type
    self.class.to_s
  end
  
  
  def to_s
    "#{@name} #{self.health_description}"
  end

  
  def health_description
    "[]#{@hp} / #{@max_hp}]"
  end
  
end
