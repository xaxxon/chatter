require 'socket'


class LoginProcess
  
  def initialize(game, user)
    @game = game
    @user = user
    
    user.send "What is your name: "
  end
  
  def handle_input(data)
    @game.get_users(:logged_in => true).each{|user| user.send "#{data} logged in"}
    @user.name = data
    @user.send "Welcome #{data}"
    return 1;
  end

end


class User
  
  attr_accessor :send_buffer
  attr_reader :socket
  
  def initialize(game, socket)
    @game = game
    @socket = socket
    @input_buffer = ""
    @name = nil
    @send_buffer = ""
    @processes = [LoginProcess.new(@game, self)]
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
    @game.get_users(:not_user => self, :logged_in => true).each{|user| user.send "#{self.name} disconnected"}
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
      if @processes.empty?
        @game.handle_input self, line
      else
        process_complete = @processes[0].handle_input line
        if process_complete
          @processes.shift
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
  end
  
  
  def get_users(logged_in: false, not_user: nil)
    users = @socket_user_map.values
    
    if logged_in
      users.select!{|user|user.logged_in?}
    end
    
    if not_user
      users.select!{|user|user != not_user}
    end
    
    users
      
  end    
  
  
  def watch_user_for_write(user)
    @sockets_with_writes_pending[user.socket] = 1
  end


  def handle_input(user, line)
    get_users(:logged_in => true, :not_user => user).each{|each_user| each_user.send line}
  end
  
  
  def handle_accept(server_socket)
      client_socket = @server_socket.accept_nonblock
      new_user = User.new self, client_socket
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