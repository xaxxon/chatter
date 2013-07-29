
require 'singleton'

class Names  

  include Singleton

  def random
    @names[Random.rand(@names.size).to_i].chomp
  end

  def initialize
    @names = []
    File.foreach("names2.txt"){|line|
      @names << line
    }
  end
  
end