import org.apache.commons.logging.Log;
import org.apache.commons.logging.LogFactory;

import java.io.IOException;
import java.io.OutputStream;
import java.nio.channels.Channels;
import java.nio.channels.Pipe;
require 'thread'
require_relative 'timer'
require_relative 'stream_piper'


##
#  Helper class that wraps Spawnables to make them crunchier for ExpectJ to run.
# 
#  @author Johan Walles
#  
class SpawnableHelper
  #include expectj.TimerEventListener

  ##
  #  @param timeOutSeconds time interval in seconds to be allowed for spawn execution
  #  @param runMe the spawnable to execute
  #  
  def initialize(runMe, timeOutSeconds, echo) 
    if (timeOutSeconds < -1)
      raise "Time-out is invalid"
    end
    if (timeOutSeconds != -1) 
      @timer = Timer.new(timeOutSeconds, self);
    end
    @spawnable = runMe;
    @echo = echo;
  end

  def timerTimedOut
    stop();
  end

  ##
  #  This method stops the spawn.
  #  
  def stop
    spawnOutToSystemOut.stopProcessing();
    if spawnErrToSystemErr != nil
      spawnErrToSystemErr.stopProcessing();
    end
    @spawnable.stop();
    close();
  end

  ##
  #  This method is invoked by the {@link Timer}, when the timer thread
  #  receives an interrupted exception.
  # 
  #  @param reason The reason we were interrupted.
  #  
  def timerInterrupted(reason) 
    # Print the stack trace and ignore the problem, this will make us never
    # time out.  Too bad.  /JW-2006apr10
    puts "Timer interrupted"
  end

  ##
  #  From now on, don't copy any piped content to stdout.
  #  @see #startPipingToStandardOut()
  #  @see Spawn#interact()
  #  
  def stopPipingToStandardOut
    self.synchronized do
      spawnOutToSystemOut.stopPipingToStandardOut();
      if (spawnErrToSystemErr != nil)
        spawnErrToSystemErr.stopPipingToStandardOut();
      end
    end
  end

  ##
  #  From now on, copy all piped content to stdout.
  #  @see #stopPipingToStandardOut()
  #  @see Spawn#interact()
  #  
  def startPipingToStandardOut
    self.synchronize do
      spawnOutToSystemOut.startPipingToStandardOut();
      if (spawnErrToSystemErr != nil) 
        spawnErrToSystemErr.startPipingToStandardOut();
      end
    end
  end

  ##
  #  This method launches our Spawnable within the specified time
  #  limit.  It tells the spawnable to start, and starts the timer when
  #  enabled. It starts the piped streams to enable copying of spawn
  #  stream contents to standard streams.
  #  @throws IOException if launching the spawnable fails
  #  
  def start
    # Start the spawnable and timer if needed
    @spawnable.start();
    if (@timer != nil)
      @timer.startTimer();
    end

    # Starting the piped streams and StreamPiper objects
    @systemOut = Pipe.open();
    @systemOut.source().configureBlocking(false);
    @copyStream = @echo# ? java.lang.System.out : nil
    spawnOutToSystemOut = StreamPiper.new(@copyStream,
                        @spawnable.getStdout(),
                        Channels.newOutputStream(@systemOut.sink()));
    puts "======"
    spawnOutToSystemOut.start();

    if (@spawnable.getStderr() != nil) 
      @systemErr = Pipe.open();
      @systemErr.source().configureBlocking(false);

      spawnErrToSystemErr = StreamPiper.new(@echo,
                          @spawnable.getStderr(),
                          Channels.newOutputStream(@systemErr.sink()));
      spawnErrToSystemErr.start();
    end
  end

  ##
  #  Shut down operations and free system resources.
  #  <p>
  #  Any exception on closing resources will be logged.
  #  
  def close()
    if (spawnErrToSystemErr != nil) 
      spawnErrToSystemErr.stopProcessing();
    end
    if (spawnOutToSystemOut != nil)
      spawnOutToSystemOut.stopProcessing();
    end
    if (systemOut != nil) 
      begin
        systemOut.sink().close();
      rescue
        puts "Closing stdout sink failed"
      end
      begin
        systemOut.source().close();
      rescue
        puts "Closing stdout source failed"
      end
    end
    if (@systemErr != nil) 
      begin
        @systemErr.sink().close();
      rescue
        puts "Closing stderr sink failed"
      end
      begin
        @systemErr.source().close();
      rescue
        puts "Closing stderr source failed"
      end
    end
  end

  ##
  #  @return a channel from which data produced by the spawn can be read
  #  
  def getStdoutChannel()
    @systemOut.source();
  end

  ##
  #  @return the output stream of the spawn.
  #  
  def getStdin
    @spawnable.getStdin();
  end

  ##
  #  @return a channel from which stderr data produced by the spawn can be read, or
  #  nil if there is no channel to stderr.
  #  
  def getStderrChannel
    if (@systemErr == nil)
      return nil;
    end
    @systemErr.source()
  end

  ##
  #  @return true if the spawn has exited.
  #  
  def isClosed
    @spawnable.isClosed();
  end

  ##
  #  If the spawn represented by this object has already exited, it
  #  returns the exit code. isClosed() should be used in conjunction
  #  with this method.
  #  @return The exit code from the exited spawn.
  #  @throws ExpectJException If the spawn is still running.
  #  
  def getExitValue 
    if !isClosed()
      raise "Spawn is still running"
    end
    @spawnable.getExitValue();
  end


  ##
  #  @return the available contents of Standard Out
  #  
  def getCurrentStandardOutContents
    spawnOutToSystemOut.getCurrentContents();
  end

  ##
  #  @return the available contents of Standard Err, or nil if stderr is not available
  #  
  def getCurrentStandardErrContents() 
    if (spawnErrToSystemErr == nil) 
      return nil;
    end
    spawnErrToSystemErr.getCurrentContents();
  end

  ##
  #  Register a listener that will be called when the spawnable we're wrapping
  #  closes.
  # 
  #  @param closeListener The listener that will be notified when this
  #  spawnable closes.
  #  
  def setCloseListener(closeListener)
    @spawnable.setCloseListener(closeListener)
  end
end
