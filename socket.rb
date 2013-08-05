require 'socket'


require './dungeon'
require './user'
require './combat'

require './asynchronous_processor'


module Kernel
  def print_stacktrace
    raise
  rescue
    $!.backtrace[1..-1].join("\n")
  end
end



class LoginProcessor

  def initialize(user)
    @game = user.game
    @user = user
    
    user.send "What is your name: "
  end
  
  
  def handle_input(data)
    @game.send "#{data} logged in\n", :logged_in => true
    @user.name = data
    @user.send "Welcome #{data}\n"
    @user.send @user.room.description(@user)
    return 1
  end

end


class CommandProcessor

  def initialize(user)
    @game = user.game
    @user = user
  end
  
  def handle_input(data)
    # if no command is present, default to saying the entire input
    command = 'say'
    remaining = data

    # check to see if there is a specific command
    if match = data.match(/^\.(\S+)\s*/)
        
      command = match[1] or "say"
      remaining = match.post_match
    end
  
    case command
    when 'say'
      @user.send "You say: #{remaining}\n"
      @user.room.send "#{@user.name} says: #{remaining}\n", not_user: @user
    when 'go'
      if @user.room.connected? remaining.to_sym
        @game.get_users(in_room: @user.room, not_user: self).send "#{@user.name} leaving to the #{remaining}"
        @user.room = @user.room.connected_room remaining
        @game.get_users(in_room: @user.room, not_user: self).send "#{@user.name} entered the room"
      else
        @user.send "#{remaining} is not an exit.  Exits are #{@user.room.connections.keys.join ", "}"
      end
    when 'look'
      @user.send @user.room.description @user
    when 'shout'
      @game.get_users(logged_in: true, not_user: @user).send "#{@user.name} shouts: #{remaining}"
    when 'attack'

      room = @user.room
      
      # attack the monsters in the current room for now
      # verify there is a monster
      if room.entities.select(&:monster?).empty?
        @user.send "Nothing to attack here"
      else
      
        # check to see if there is already combat in the room
        if combat = room.combat
          combat.add_entity @user, room.entities.select(&:is_monster?)[0]
        else
          room.combat = Combat.new @game, room, [@user, room.entities.select(&:monster?)[0]], room.entities.select(&:monster?).map{|monster| [monster, @user]}
        end
      end
    else
      @user.send "#{command} is not a known command"
    end
    
    return false; # this never returns true
  end
  
end



class Game
  
  include EntityCollection
  
  attr_reader :server_socket
  
  def inspect(*stuff)
    "Game: #{@socket_user_map.size} users connected"
  end
  
  def add_asynchronous_processors(*stuff)
    @asynchronous_processors.concat stuff
  end
  
  
  def initialize

    # when set to true via game.done, game.go will exit before the next processing loop
    @done = false
 
    # up-to-date list of sockets which have data pending to be written
    @sockets_with_writes_pending = {}

    # fast lookup for user objects by socket
    @socket_user_map = {}

    while true
      @dungeon = Dungeon.new self, 10, 10
      #@dungeon.print
      break if @dungeon.rooms[0][0].connected_room_count > 50
    end

    # Processors to run periodically, not based on user input
    @asynchronous_processors = []
    #@asynchronous_processors = [DoStuff.new(self), DoOtherStuff.new(self)]
    @wakeup_time = 0
  end

  
  def open_server_socket
    hostname = ''
    port = 2000
    @server_socket = TCPServer.open(hostname, port)
    @server_socket.setsockopt(Socket::SOL_SOCKET,Socket::SO_REUSEADDR, true)
  end
  

  def all_entities
    @socket_user_map.values
  end
  
    
  def watch_user_for_write(user)
    @sockets_with_writes_pending[user.socket] = 1
  end
  
  
  def starting_room
    @dungeon.rooms[0][0]
  end
  
  
  def handle_accept(server_socket)
      client_socket = @server_socket.accept_nonblock
      new_user = User.new self, client_socket, self.starting_room
      @socket_user_map[client_socket] = new_user
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
    
    bytes_written = socket.write_nonblock(user.send_buffer)
    
    if bytes_written == user.send_buffer.size
      @sockets_with_writes_pending.delete(socket)
    end
    
    user.send_buffer = user.send_buffer[bytes_written..-1]
  end
  
  
  def handle_asynchronous_processors(time)
    
    # Run all the processors and give them all the same timestamp so
    #   they make consistent decisions
    # Remove completed ones
    @asynchronous_processors.each{|processor| 
      processor.run time
    }.reject!(&:complete?)

    if @asynchronous_processors.empty?
      @wakeup_time = nil
    else
      # determine the time to run processors again
      after_run_time = Time.now
      @wakeup_time = @asynchronous_processors.map(&:time_til_next_run).min - (after_run_time - time)
    end    

  end
  

  def done?
    @done
  end
  
  
  def done
    @done = true
  end 


  def select_sockets
    IO.select(@socket_user_map.keys + [@server_socket], @sockets_with_writes_pending.keys, [], @wakeup_time)
  end
  
  
  def run_once

    async_start_time = Time.now # the time to send to all the async proc. run methods
    self.handle_asynchronous_processors async_start_time


    # returns nil on timeout
    reads = writes = nil
    if @asynchronous_processors.empty? or @wakeup_time > 0
      reads, writes = select_sockets
    end

    # handle writes if select didn't timeout
    writes.each{|socket|
      handle_write socket
    } unless writes.nil?

    
    # handle reads if select didn't timeout
    reads.each{|socket|

      if socket === @server_socket
        handle_accept socket
      else
        handle_client_input socket
      end
    } unless reads.nil?
    
  end


  def go

    open_server_socket()

    until done? do
      self.run_once
    end
    
    true
    
  end
  
end
