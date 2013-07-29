require './entity'

require './weapon'
require './names'



class Goblin < Entity
  
  def initialize(room)
    super room, 40, Dagger.new, Names.instance.random
  end
  
end


