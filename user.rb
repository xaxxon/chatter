

# list of users as returned by get_users
class UserList

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


class User

  attr_accessor :send_buffer, :room
  attr_reader :socket, :game
  
  
  def initialize(game, socket, room)
    @game = game
    @socket = socket
    @input_buffer = ""
    @name = nil
    @send_buffer = ""
    @processors = [LoginProcessor.new(self), CommandProcessor.new(self)]
    @room = room
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
    @send_buffer << data << "\r\n"
    @game.watch_user_for_write self
  end
  
  
  def disconnect(remote_disconnect: false )
    # tell the other users this user disconnected
    @game.get_users(:not_user => self, :logged_in => true).send "#{self.name} disconnected"
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

