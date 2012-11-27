java_import java.io.IOException;
java_import java.io.InputStream;
java_import java.io.OutputStream;

##
#  This class spawns a process that ExpectJ can control.
# 
#  @author Sachin Shekar Shetty
#  @author Johan Walles
# /
class ProcessSpawn 

  ##
  #  This constructor allows to run a process with indefinite time-out
  #  @param executor Will be called upon to create the new process
  # /
  def initialize(executor)
    if (executor == nil) 
      raise "Executor is null, must get something to run"
    end

    # Initialise the process thread.
    @process_thread = ProcessThread.new(executor);
  end

  ##
  #  This method stops the spawned process.
  # /
  def stop
    @process_thread.stop();
  end

  ##
  #  This method executes the given command within the specified time
  #  limit. It starts the process thread and also the timer when
  #  enabled. It starts the piped streams to enable copying of process
  #  stream contents to standard streams.
  #  @throws IOException on trouble launching the process
  # /
  def start
    # Start the process
    @process_thread.start();
  end

  ##
  #  @return the input stream of the process.
  # /
  def getStdout
    @process_thread.process.getInputStream();
  end

  ##
  #  @return the output stream of the process.
  # /
  def getStdin
    @process_thread.process.getOutputStream();
  end

  ##
  #  @return the error stream of the process.
  # /
  def getStderr
    @process_thread.process.getErrorStream();
  end

  ##
  #  @return true if the process has exited.
  # /
  def isClosed
    @process_thread.isClosed;
  end

  ##
  #  If the process representes by this object has already exited, it
  #  returns the exit code. isClosed() should be used in conjunction
  #  with this method.
  #  @return The exit code of the finished process.
  #  @throws ExpectJException if the process is still running.
  # /
  def getExitValue
    if (!isClosed()) 
      raise "Process is still running"
    end
    @process_thread.exitValue;
  end

  ##
  #  This class is responsible for executing the process in a separate
  #  thread.
  # /
  class ProcessThread 
    attr_accessor :process
    include java.lang.Runnable

    ##
    #  Prepare for starting a process through the given executor.
    #  <p>
    #  Call {@link #start()} to actually start running the process.
    # 
    #  @param executor Will be called upon to start the new process.
    # /
    def initialize(executor) 
      @executor = executor;
    end

    ##
    #  This method spawns the thread and runs the process within the
    #  thread
    #  @throws IOException if process spawning fails
    # /
    def start
      @thread = Thread.new {
        run
      }
      puts "==== spawn_start"
      @process = @executor.execute();
    end

    ##
    #  Wait for the process to finish
    # /
    def run
      begin
        @process.waitFor();
        exitValue = @process.exitValue();
        isClosed = true;
        onClose();
      rescue
      end
    end

    ##
    #  This method interrupts and stops the thread.
    # /
    def stop
      @process.destroy();
      begin
        @thread.join();
      rescue
        # Process should have died when calling process.destroy().
        # After that, process.waitFor() should return, causing the
        # run() method above to terminate.
      end
    end
  end

end
