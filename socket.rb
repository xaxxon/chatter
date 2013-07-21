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
  
  attr_reader :socket
  attr_accessor :send_buffer
  
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
  
  def initialize(game, socket)
    @game = game
    @socket = socket;
    @input_buffer = ""
    @send_buffer = ""
    @processes = [LoginProcess.new(@game, self)]
  end
  
  # queues up data to be sent to the client
  def send(data)
    puts "Sending #{data} to #{self.socket}"
    @send_buffer << data << "\r\n"
    @game.watch_user_for_write self
  end
  
  
  
  def disconnect(remote_disconnect: false )
      
  end
  
  
  def handle_input(data)
    
    @input_buffer << data

    @input_buffer.each_line{|line|

      if line.end_with? $/
        line.chomp!

        if @processes.empty?
          @game.handle_input self, line
        else
          process_complete = @processes[0].handle_input line
          if process_complete
            @processes.shift
          end
        end
      else
        @input_buffer = line
        break
      end
    }
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
  
  def get_users(flags)
    users = @socket_user_map.values
    
    if flags[:logged_in]
      users.select!{|user|user.logged_in?}
    end
    
    if flags[:not_user]
      users.select!{|user|user != flags[:not_user]}
    end
    
    users
      
  end
  

  def handle_input(user, line)
    get_users(:logged_in => true, :not_user => user).each{|each_user| each_user.send line}
  end


  # Have to call this to send to a user, because this tracks whether a user's socket needs
  #   to be selected for writing
  def watch_user_for_write(user)
    @sockets_with_writes_pending[user.socket] = 1;
  end
  
  
  def handle_accept(server_socket)
      client_socket = @server_socket.accept_nonblock
      new_user = User.new(self, client_socket)
      @socket_user_map[client_socket] = new_user    
  rescue Exception => e
    puts "Unknown accept error: ", e.inspect
  end


  def handle_client_input(socket)
    # look up user object for this socket
    user = @socket_user_map[socket];
    # read the data, but handle EOF if the client disconnected
    data = socket.read_nonblock 4096
    
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
    send_buffer = user.send_buffer
    
    bytes_written = socket.write_nonblock(send_buffer)
    
    if bytes_written = send_buffer.size
      @sockets_with_writes_pending.delete(socket)
    end
    user.send_buffer = send_buffer[bytes_written..-1]
    
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