#测试While修饰符
require 'xcodeproj'
# [code] while [condition] , 当condition为真，执行code


class TestWhile
  attr_accessor :uuids ,:index
  def initialize
    self.uuids = []
    self.index = 0
  end
  def genarate_uuid_list
    puts "genarate_uuid_list call"
    if self.index != 0
      self.uuids += ["add"]
    end
    self.index += 1
  end
  
  def genarate_uuid
      genarate_uuid_list while self.uuids.empty?
      self.uuids
  end
  
end


test = TestWhile.new
uuids = test.genarate_uuid
puts "one:#{uuids}"
uuids = test.genarate_uuid
puts "two:#{uuids}"

# 卧槽，还有这种操作？
puts "three#{uuids}" if not uuids.empty?


