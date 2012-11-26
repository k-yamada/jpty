require 'spec_helper'

describe JPTY do
  describe ".sh" do
    it "should expect echo" do
      shell = JPTY.spawn("/bin/sh", 5)
      shell.send("echo Chunder\n")
      shell.expect("Chunder")
    end
  end
end
