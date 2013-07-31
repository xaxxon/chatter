# AsynchronousProcessor must implement
#   initialize(game) - takes a game object for optional use later
#   run(time) - actual processing work goes here
#   complete? - is this processor done?  if true, object will be removed
#   time_til_next_run - how many seconds from now (float) should this processor be called next?

# Includeable module for your asynchronous processor
# If you include this, just implement _run(time)
#   and redefine period_seconds to how often the function should be called
module AsynchronousProcessorBase
  
  
  def period_seconds
    @period_seconds or 1
  end

  # Calls _run if the correct amount of time has passed since the previous call
  #   passes in elapsed time since last call
  def run(time)
    @most_recent_time_called ||= nil
    @previous_execution_time ||= Time.now
    @most_recent_time_called = time
    if time > @previous_execution_time + @period_seconds
      @previous_execution_time += @period_seconds # not the ACTUAL time called, but the time it SHOULD have been called otherwise we'll always lag
      @complete = self._run
    end
  end


  # default to never completing unless overwritten in base class
  def complete?
    @complete or false
  end
  

  # compute how much time is remaining until the next time this processor should be called
  def time_til_next_run
    @previous_execution_time - @most_recent_time_called + @period_seconds
  end

end



class DoOtherStuff
  include AsynchronousProcessorBase
  def initialize(game)
    @game = game
    @period_seconds = 3
  end
  
  
  def _run
    self.game.get_users(logged_in: true).send "This is your #{@period_seconds}-second update #{Time.now}"
  end
  
end



class DoStuff
  include AsynchronousProcessorBase

  def initialize(game)
    @game = game
    @period_seconds = 7
  end


  def _run
    self.game.get_users(logged_in: true).send "This is your #{@period_seconds}-second update #{Time.now}"
  end
  
end

