require_relative '../java_libs/jsch-0.1.31.jar'
require_relative 'process_spawn'
java_import "com.jcraft.jsch.Channel"
java_import "java.io.IOException"
java_import "java.net.UnknownHostException"

##
#  This class is the starting point of the ExpectJ Utility. This class
#  acts as factory for all {@link Spawn}s.
# 
#  @author	Sachin Shekar Shetty
# /
class ExpectJ 

  ##
  #  Create a new ExpectJ with specified timeout setting.
  #  @param defaultTimeoutSeconds default time out in seconds for the expect
  #  commands on the spawned process.  -1 default time out indicates
  #  @param echo indicates whether the spawn output is echoed to the console.
  # /
  def initialize(defaultTimeoutSeconds=-1, echo=true) 
    @m_lDefaultTimeOutSeconds = defaultTimeoutSeconds
    @m_bEcho = echo;
  end

  ##
  #  This method launches a {@link Spawnable}. Further expect commands can be
  #  invoked on the returned {@link Spawn} object.
  # 
  #  @param spawnable spawnable to be executed
  #  @return The newly spawned process
  #  @throws IOException if the spawning fails
  # /
  def launch_spawn(spawnable) 
    Spawn.new(spawnable, @m_lDefaultTimeOutSeconds, @m_bEcho);
  end

  ##
  #  This method spawns a new process. Further expect commands can be invoked
  #  on the returned {@link Spawn} object.
  # 
  #  @param command command to be executed
  #  @return The newly spawned process
  #  @throws IOException if the process spawning fails
  #  @see Runtime#exec(String)
  # /
  class MyExecutor
    def initialize(command)
      @command = command
    end

    def execute
      java.lang.Runtime.getRuntime().exec(@command);
    end

    def toString() 
      command;
    end
  end

  def spawn(command) 
    launch_spawn(ProcessSpawn.new(MyExecutor.new(command)))
  end

  ##
  #  This method spawns a new process. Further expect commands can be invoked
  #  on the returned {@link Spawn} object.
  # 
  #  @param executor Will be called upon to start the new process
  #  @return The newly spawned process
  #  @throws IOException if the process spawning fails
  #  @see Runtime#exec(String[])
  # /
  def spawn_executor(executor)
    spawn(ProcessSpawn.new(executor))
  end

  ##
  #  This method spawns a telnet connection to the given host and port number.
  #  Further expect commands can be invoked on the returned {@link Spawn}
  #  object.
  # 
  #  @param hostName The name of the host to connect to.
  #  @param port The remote port to connect to.
  #  @return The newly spawned telnet session.
  #  @throws IOException if the telnet spawning fails
  #  @throws UnknownHostException if you specify a bogus host name
  # 
  #  @see TelnetSpawn
  #  @see #spawn(String, int, String, String)
  #  @see #spawn(Channel)
  # /
  def spawn_telnet(hostName, port)
    spawn(TelnetSpawn.new(hostName, port))
  end

  ##
  #  This method creates a spawn that controls an SSH connection.
  # 
  #  @param channel The SSH channel to control.
  # 
  #  @return A spawn controlling the SSH channel.
  # 
  #  @throws IOException If taking control over the SSH channel fails.
  # 
  #  @see #spawn(String, int, String, String)
  # 
  #  @see SshSpawn#SshSpawn(Channel)
  # /
  def spawn_channel(channel) 
    spawn(SshSpawn.new(channel));
  end

  ##
  #  This method creates a spawn that controls an SSH connection.
  # 
  #  @param remoteHostName The remote host to connect to.
  # 
  #  @param remotePort The remote port to connect to.
  # 
  #  @param userName The user name with which to authenticate
  # 
  #  @param password The password with which to authenticate
  # 
  #  @return A spawn controlling the SSH channel.
  # 
  #  @throws IOException If taking control over the SSH channel fails.
  # 
  #  @see #spawn(Channel)
  # 
  #  @see SshSpawn#SshSpawn(String, int, String, String)
  # /
  def spawn_ssh(remoteHostName, remotePort, userName, password) 
    spawn(SshSpawn.new(remoteHostName, remotePort, userName, password));
  end
end
