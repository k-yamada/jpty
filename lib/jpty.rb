require "jpty/version"
require 'java'
require 'java_libs/expectj-2.0.7.jar'
require 'java_libs/jsch-0.1.31.jar'
require 'java_libs/commons-logging-1.1.1.jar'
#java_import 'expectj.ExpectJ'
java_import 'expectj.ExpectJException'
#java_import 'expectj.Spawn'
java_import 'expectj.TimeoutException'
java_import 'java.io.IOException'
require_relative 'jpty/spawn'
require_relative 'jpty/expectj'

module JPTY

  class << self
    def spawn(command, timeout_sec=-1)
      expectinator = ExpectJ.new(timeout_sec)
      expectinator.spawn(command)
    end
  end

end
