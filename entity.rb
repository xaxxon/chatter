

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
    # no-op
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


# list of users as returned by get_users
class EntityList

  include Enumerable

  def initialize(user_list)
    @user_list = user_list
  end


  def each
    @user_list.each{|user|
      yield user
    }
  end


  def send(data)
    @user_list.each{|user|
      user.send data
    }
  end

end


# anything that has a collection of entities should include this module
# Including class must implement all_entities to return an Enumerable of all entities in the collection
# Usage: object_of_class_with_entitycollection.entities(not_user: some_user).send "hi everyone else"
module EntityCollection
  
  
  def all_entities
    raise "Class using EntityCollection must override entities to return all the entities in the collection"
  end
  
  
  def entities(**params)
    EntityList.new(filter_users(all_entities, **params))
  end
  
  
  def send(message, **params)
    entities(**params).send message
  end
  
  
  def filter_users(users, logged_in: nil, not_user: nil, in_room: nil)
        
    if in_room
      users = users.select{|user|user.room == in_room}
    end
    
    if logged_in != nil
      users = users.select{|user|user.logged_in? == logged_in}
    end
    
    if not_user
      users = users.select{|user|user != not_user}
    end
    
    UserList.new users
      
  end
  
  
  
end

