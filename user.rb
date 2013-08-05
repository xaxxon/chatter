
require './entity'


class User < Entity

  attr_accessor :send_buffer
  attr_reader :socket, :weapon
  
    
  def initialize(game, socket, room)
    super(game, room, 40, Sword.new, "unnamed")
    @socket = socket
    @input_buffer = ""
    @name = nil
    @send_buffer = ""
    @processors = [LoginProcessor.new(self), CommandProcessor.new(self)]
    @room = room
  end
    
  def hp=(hp)
    puts "Users don't take damage yet"
    @hp=@max_hp
  end
  
  def monster?
    return false
  end
  
  def inspect(*thing)
    "User: #{self} #{@name}"
  end
  

  def name=(name)
    raise "Cannot change name" if @name != nil
    @name = name
  end


  def name
    return @name
  end


  def logged_in?
    @name != nil
  end


  # queues up data to be sent to the client
  def send(data)
    @send_buffer << data
    @game.watch_user_for_write self
  end


  def disconnect(remote_disconnect: false )
    # tell the other users this user disconnected
    @game.get_users(:not_user => self, :logged_in => true).send "#{self.name} disconnected"
  end


  def update_status
    if self.dead?
      
      @combat.remove_entity self
      
      self.room.send "#{self.name} is dead"
      self.room.send "#{self.name} dematerializes from the room"      
      
      self.room = @game.starting_room
      self.room.send "#{self.name} materializes into the room"
      
    end
  end


  def handle_input(data)
    puts "in user::Handle_input"  
    puts "input buffer starting at #{@input_buffer}"
    @input_buffer << data
    puts "input buffer now at #{@input_buffer}"

    position = 0;
    while match = @input_buffer.match(/^(.*?)[\r\n]+/, position)
      position = match.end(0)
      line = match[1]
      if line.empty?
        puts "Empty line from user skipped"
        next 
      end
      if @processors.empty?
        @game.get_users(in_room: self.room).send line
      else
        processor_complete = @processors[0].handle_input line
        if processor_complete
          puts @processors.shift.inspect
          puts "processors remaining #{@processors.size}"
        end
      end
    end
    # trim off the handled input so just the unhandled input remains
    @input_buffer = @input_buffer[position..-1]
  end
end

