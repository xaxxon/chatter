

class Entity
  
  attr_accessor :hp
  attr_reader :name, :room
  
  def initialize(room, hp, weapon, name)
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
  
  def dead?(*stuff)
    puts self
    self.hp <= 0
  end
  
  def is_monster?
    return true;
  end
  
  # no-op for NPCs, otherwise it sends to user
  def send(data)
    
  end
  
end
