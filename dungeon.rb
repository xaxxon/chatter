require './monster'

class Room
  
  attr_reader :connections, :dungeon
  
  def initialize(dungeon, x, y)
    @connections = {}
    @dungeon = dungeon
    @x = x
    @y = y
    @entities = {Goblin.new(self) => nil}
    @combat = nil
  end
  
  def entities
    @entities.keys
  end
  
  def combat
    return @combat
  end
  
  def combat=(combat)
    puts "About to call add_async"
    self.dungeon.game.add_asynchronous_processors combat
    puts "Done calling it"
  end
  
  def add_entity(entity)
    @entities[entity] = 1
  end
  
  def remove_entity(entity)
    @entities.delete entity
  end
  
  def inspect(*thing)
    "Room: #{self} '#{@x}' '#{@y}' has connections to the: [#{@connections.keys.map{|direction|direction.to_s}.join ", "}]"
  end
  
  
  def connect(direction, room)
    @connections[direction] = room
  end
  
  def connected?(direction)
    @connections.key? direction
  end
  
  def connected_rooms
    return @connections.keys
  end
  
  def connected_room(direction)
    @connections[direction.to_sym]
  end
  
  def connected_room_count
    rooms_found = {}
    room_deque = [self]
    while room_deque.size > 0
      current_room = room_deque.shift
      unless rooms_found.key? current_room
        rooms_found[current_room] = 1
        room_deque.concat current_room.connections.values
      end
    end
    return rooms_found.values.size
  end
   
   
  def monsters
    self.entities.select(&:monster?)
  end

  # send a message to all logged-in users in the room
  # takes all the same parameters as get_users, but always sends in_room: self
  def send(message, **params)
    @dungeon.game.get_users(in_room: self, logged_in: true, **params).send message
  end
  
   
  def description(user)
    other_users_in_room = @dungeon.game.get_users(in_room: self, not_user: user).map{|u|u.name}
    other_users_text =
      if other_users_in_room.empty?
        "No other players are present\n"
      else
        other_users_in_room.join(", ") + (if other_users_in_room.size == 1 then " is " else " are " end) + "in the room with you\n"
      end
      
    self.monsters.each{|monster| other_users_text += "#{monster.name} the #{monster.type}\n"}
    
  
    "You are in a room.\nThere are exits to the: #{@connections.keys.join ","}\n#{other_users_text}"
    
  end
   
end

class Dungeon
  
  attr_reader :rooms, :game
  
  def initialize(game, x,y)
    @game = game
    @x = x
    @y = y
    @random = Random.new(Time.now.to_i)
    
    # Create 2D grid of rooms
    @rooms = []
    x.times{|i|
      column = []
      y.times{|j|
        column << Room.new(self, i, j)
      }
      @rooms << column
    }
    
    room_splitter(0, 0, x - 1, y - 1)
  end
  
  
  
  def print
    string = ""
    @y.times{|y|
      @x.times{|x|
        room = @rooms[x][y]
        string << if room.connected?(:north) then " | " else "   " end
      }
      string << "\n"
      
      @x.times{|x|
        room = @rooms[x][y]
        string << if room.connected? :west then "-" else " " end
        string << "*"
        string << if room.connected? :east then "-" else " " end
      }
      string << "\n"
      
      @x.times{|x|
        room = @rooms[x][y]
        string << if room.connected?(:south) then " | " else "   " end
      }
      string << "\n"
      
    }
    puts string
    
  end
  
  def room_splitter(min_x, min_y, max_x, max_y)
    
    
    split_x = nil
    split_y = nil
    
    
    if min_x < max_x
      split_x = @random.rand(max_x - min_x).to_i + min_x
    end
    
    if min_y < max_y
      split_y = @random.rand(max_y - min_y).to_i + min_y
      
    end  
    
    
    chambers = []
    
    if split_x != nil
      if split_y != nil
        
        left_door = @random.rand(split_x + 1 - min_x) + min_x
        right_door = @random.rand(max_x + 1 - split_x) + split_x
        high_door = @random.rand(split_y + 1 - min_y) + min_y
        low_door = @random.rand(max_y + 1 - split_y) + split_y
        
        
        @rooms[split_x][high_door].connect :east, @rooms[split_x + 1][high_door]
        @rooms[split_x + 1][high_door].connect :west, @rooms[split_x][high_door]

        @rooms[split_x][low_door].connect :east, @rooms[split_x + 1][low_door]
        @rooms[split_x + 1][low_door].connect :west, @rooms[split_x][low_door]
        
        @rooms[left_door][split_y].connect :south, @rooms[left_door][split_y + 1]
        @rooms[left_door][split_y + 1].connect :north, @rooms[left_door][split_y]

        @rooms[right_door][split_y].connect :south, @rooms[right_door][split_y + 1]
        @rooms[right_door][split_y + 1].connect :north, @rooms[right_door][split_y]
        
        chambers << [min_x, min_y, split_x, split_y]
        chambers << [min_x, split_y+1, split_x, max_y]
        chambers << [split_x+1, min_y, max_x, split_y]
        chambers << [split_x+1, split_y+1, max_x, max_y]
      else
        # only splitting x (vertical line)
        
        door_height = @random.rand(max_y + 1 - min_y) + min_y
        
        @rooms[split_x][door_height].connect :east, @rooms[split_x + 1][door_height]
        @rooms[split_x + 1][door_height].connect :west, @rooms[split_x][door_height]
        
        
        chambers << [min_x, min_y, split_x, max_y]
        chambers << [split_x+1, min_y, max_x, max_y]
      end

    else
      # only splitting y (horizontal line)
      if split_y
        
        door_over = @random.rand(max_x + 1 - min_x) + min_x
        
        @rooms[door_over][split_y].connect :south, @rooms[door_over][split_y + 1]
        @rooms[door_over][split_y + 1].connect :north, @rooms[door_over][split_y]
        
        chambers << [min_x, min_y, max_x, split_y]
        chambers << [min_x, split_y + 1, max_x, max_y]
        
      else
        # not splitting anything - already 1x1
        return
      end
    end
    
    chambers.each{|points|
      room_splitter(*points)
    }
    
  end
    
end
