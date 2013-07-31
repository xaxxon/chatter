
require 'singleton'

class Names  

  include Singleton

  def random
    @names[Random.rand(@names.size).to_i].chomp
  end

  def initialize
    @names = []
    File.foreach("names.txt"){|line|
      @names << line
    }
  end
  
end