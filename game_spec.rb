
require './socket'

describe Game do
  
  before(:each) do
    @game = Game.new
    @game.stub(:open_server_socket).and_return 3
    IO.stub(:select).and_return([],[],[])
    
    class TestAsynchronousProcessor
      def initialize(game)
      end
      def run(time)
      end
      def complete?
        false
      end
      def time_til_next_run
        0
      end
    end
    
    class TestAsynchronousProcessorBase
      include AsynchronousProcessorBase
      def initialize
        @period_seconds = 0
      end
      def _run
      end
    end
    
  end
  
  
  it "starts out set up to run forever" do
    @game.done?.should == false
    @game.done?.should == false
    @game.done?.should == false
  end
  
  
  it "stops running once told to" do
    @game.done?.should == false
    @game.done
    @game.done?.should == true
    @game.go.should == true
  end
  
  
  it "should run asynchronous processors" do
    
    processor = TestAsynchronousProcessor.new @game
    processor.should_receive(:run).exactly(2).times
    @game.add_asynchronous_processors processor
    @game.run_once
    @game.run_once
    
  end

  
  it "should run asynchronous processors base each time through run_once" do
    
    processor = TestAsynchronousProcessorBase.new
    processor.should_receive(:_run).exactly(2).times
    @game.add_asynchronous_processors processor
    @game.run_once
    @game.run_once
    
  end
  
  
  it "should run asynchronous processors base - only once if called quickly with long @period_seconds" do
    
    class TestAsynchronousProcessorBase
      def period_seconds
        1000
      end
    end
    
    processor = TestAsynchronousProcessorBase.new
    processor.should_receive(:_run).exactly(1).times
    @game.add_asynchronous_processors processor
    @game.run_once
    @game.run_once
    
  end


end
    
