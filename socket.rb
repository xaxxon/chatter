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
  attr_accessor :name
  
  def name(name = nil)
    if name != nil
      raise "Cannot change name" if @name != nil
      @name = name
    else
      @name
    end
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
  
  # actually sends data to client with a single call to write
  def write_to_socket
    bytes_written = socket.write_nonblock(@send_buffer)
    @send_buffer = @send_buffer[bytes_written..-1]
    return @send_buffer.size
  end
  
  
  # returns whether the user has disconnected
  def handle_input
    begin
      begin
        # read the data, but handle EOF if the client disconnected
        data = socket.read_nonblock 4096
      rescue EOFError => e
        return true;
      rescue Exception => e
        puts "Unknown read error: ", e
        p e.backtrace
      end
        
      @input_buffer << data
      p "input buffer now: ", @input_buffer
      @input_buffer.each_line{|line|
        puts "Dealing with line #{line}"
        if line.end_with? $/
          line.chomp!
          puts "process count #{@processes.size}"
          if @processes.empty?
            puts "Sending to game #{@game} handle input"
            @game.handle_input self, line
          else
            process_complete = @processes[0].handle_input line
            if process_complete
              @processes.shift
              puts "#{@processes.size} processes remaining"
            end
          end
        end   
      }
      p "done with lines"
    end
    return false; # user has not disconnected
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
    
    puts "get_users returning #{users.size} users"
    users
      
  end

  def handle_input(user, line)
    puts "Handing input for #{user.name} data #{line}"
    get_users(:logged_in => true, :not_user => user).each{|user| user.send line}
  end

  # Have to call this to send to a user, because this tracks whether a user's socket needs
  #   to be selected for writing
  def watch_user_for_write(user)
    @sockets_with_writes_pending[user.socket] = 1;
    puts "watching #{@sockets_with_writes_pending.size}"
  end

  def go
    while true do

      puts "calling select"
      reads, writes = IO.select(@socket_user_map.keys + [@server_socket], @sockets_with_writes_pending.keys);
      puts "Back from select"

      # handle writes
      writes.each{|socket|
        @sockets_with_writes_pending.delete(socket) unless @socket_user_map[socket].write_to_socket > 0
      }

      reads.each{|socket|

        if socket === @server_socket
          begin
            client_socket = @server_socket.accept_nonblock
          rescue Exception => e
            puts "Unknown accept error: ", e.inspect
          end
    
          new_user = User.new(self, client_socket)
    
          @socket_user_map[client_socket] = new_user
    
        else
    
          # look up user object for this socket
          user = @socket_user_map[socket];
    
          begin
            disconnected = user.handle_input
            @socket_user_map.delete socket if disconnected
            next;
          end
    
        end

      }
    end
  end
end


Game.new.go