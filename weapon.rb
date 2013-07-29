class Weapon
  
  attr_reader :damage
  
  def initialize(damage)
    @damage = damage
  end
  
  def name
    self.class.to_s
  end
  
end


class Sword < Weapon
  def initialize
    super 8
  end
end

class Dagger < Weapon
  def initialize
    super 4
  end
  
end