# AsynchronousProcessor must implement
#   initialize(game) - takes a game object for optional use later
#   run(time) - actual processing work goes here
#   complete? - is this processor done?  if true, object will be removed
#   time_til_next_run - how many seconds from now (float) should this processor be called next?

# Base class for asynchronous processor
# If you inherit from this, implement _run(time)
#   and override @period_seconds to be called that often (must override after calling super for base class constructor)
class AsynchronousProcessorBase
  
  attr_reader :game

  def initialize(game)
    @game = game
    
    # override this to control how often the processor is called
    @period_seconds = 1
    
    # the time the main code ran last
    @previous_execution_time = Time.now
    
    # the time the system last called #run regardless
    #   of whether it chose to run or not
    @most_recent_time_called = nil
    
  end

  # Calls _run if the correct amount of time has passed since the previous call
  #   passes in elapsed time since last call
  def run(time)
    @most_recent_time_called = time
    if time > @previous_execution_time + @period_seconds
      @previous_execution_time += @period_seconds # not the ACTUAL time called, but the time it SHOULD have been called otherwise we'll always lag
      self._run
    end
  end


  # default to never completing unless overwritten in base class
  def complete?
    false
  end
  

  # compute how much time is remaining until the next time this processor should be called
  def time_til_next_run
    @previous_execution_time - @most_recent_time_called + @period_seconds
  end
  
end



class DoOtherStuff < AsynchronousProcessorBase
  def initialize(game)
    super game
    @period_seconds = 3
  end
  
  def _run
    self.game.get_users(logged_in: true).send "This is your #{@period_seconds}-second update #{Time.now}"
  end
  
end



class DoStuff < AsynchronousProcessorBase

  def initialize(game)
    super game
    @period_seconds = 7
  end


  def _run
    self.game.get_users(logged_in: true).send "This is your #{@period_seconds}-second update #{Time.now}"
  end
  
end

