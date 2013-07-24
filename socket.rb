require 'socket'

require './dungeon'


class LoginProcessor
  
  def initialize(user)
    @game = user.game
    @user = user
    
    user.send "What is your name: "
  end
  
  def handle_input(data)
    @game.get_users(:logged_in => true).send "#{data} logged in"
    @user.name = data
    @user.send "Welcome #{data}"
    @user.send @user.room.description
    return 1
  end
end

class CommandProcessor
  
  def initialize(user)
    @game = user.game
    @user = user
  end
  
  def handle_input(data)
    command = 'say'
    remaining = data
    if match = data.match(/^\.(\S+)\s*/)
        
      command = match[1] or "say"
      remaining = match.post_match
    end
      
    
    puts "Command #{command} remaining #{remaining}"
    
    return false; # this never returns true
  end
  
  def command(data)
    

    
  end
  
end


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

  attr_accessor :send_buffer
  attr_reader :socket, :room, :game
  
  
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




class Game
  
  def initialize
    
    # up-to-date list of sockets which have data pending to be written
    @sockets_with_writes_pending = {}
    
    # fast lookup for user objects by socket
    @socket_user_map = {}
    
    hostname = ''
    port = 2000

    @server_socket = TCPServer.open(hostname, port)

    while true
      @dungeon = Dungeon.new 10, 10
      @dungeon.print
      break if @dungeon.rooms[0][0].connected_room_count > 50
    end

  end
  
  
  def get_users(logged_in: nil, not_user: nil, in_room: nil)
    users = @socket_user_map.values
    
    if in_room
      users.select!{|user|user.room == in_room}
    end
    
    if logged_in != nil
      users.select!{|user|user.logged_in? == logged_in}
    end
    
    if not_user
      users.select!{|user|user != not_user}
    end
    
    UserList.new users
      
  end
  
  
  def watch_user_for_write(user)
    @sockets_with_writes_pending[user.socket] = 1
  end


  def handle_input(user, line)
    get_users(:logged_in => true, :not_user => user).send line
  end
  
  
  def handle_accept(server_socket)
      client_socket = @server_socket.accept_nonblock
      new_user = User.new self, client_socket, @dungeon.rooms[0][0]
      @socket_user_map[client_socket] = new_user
  end


  def handle_client_input(socket)
    # look up user object for this socket
    user = @socket_user_map[socket];
    # read the data, but handle EOF if the client disconnected
    data = socket.read_nonblock 4096
    puts "read #{data}"
    
    user.handle_input data

  rescue EOFError
    # handle any application-level cleanup for the user leaving
    user.disconnect(:remote_disconnect => true)
  
    # remove the user from the select sockets - read and write
    @socket_user_map.delete socket
    @sockets_with_writes_pending.delete socket
  end


  def handle_write(socket)
    
    user = @socket_user_map[socket]
    puts "about to send #{user.send_buffer}"
    
    bytes_written = socket.write_nonblock(user.send_buffer)
    puts "wrote #{bytes_written}"
    
    if bytes_written == user.send_buffer.size
      @sockets_with_writes_pending.delete(socket)
    end
    
    puts "new buffer is #{user.send_buffer[bytes_written..-1]}"
    user.send_buffer = user.send_buffer[bytes_written..-1]
    puts "buffer is now: #{user.send_buffer}" 
  end
  

  def go
    
    puts "Game running.."
    
    while true do

      reads, writes = IO.select(@socket_user_map.keys + [@server_socket], @sockets_with_writes_pending.keys);

      # handle writes
      writes.each{|socket|
        handle_write socket
      }

      reads.each{|socket|

        if socket === @server_socket
          handle_accept socket
        else
          handle_client_input socket
        end
      }
    end
  end
  
end


Game.new.go