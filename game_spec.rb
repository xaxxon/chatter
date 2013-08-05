
require './socket'

describe Game do
  
  before(:each) do
    @game = Game.new
    @game.stub(:open_server_socket).and_return 3
    
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
    
    processor = TestAsynchronousProcessor.new @game
    processor.should_receive(:run).exactly(2).times
    @game.add_asynchronous_processors processor
    @game.run_once
    @game.run_once
    
    
  end

end
    
