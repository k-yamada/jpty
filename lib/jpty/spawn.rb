java_import java.io.BufferedWriter;
java_import java.io.IOException;
java_import java.io.OutputStreamWriter;
java_import java.nio.ByteBuffer;
java_import java.nio.channels.Channels;
java_import java.nio.channels.Pipe;
java_import java.nio.channels.SelectionKey;
java_import java.nio.channels.Selector;
java_import java.util.Date;

##
#  This class is used for talking to processes / ports. This will also interact
#  with the process to read and write to it.
# 
#  @author	Sachin Shekar Shetty

class Spawn 

  def log(str)
    puts str
  end
  
  ##
  #  Constructor
  # 
  #  @param spawn This is what we'll control.
  #  @param lDefaultTimeOutSeconds Default timeout for expect commands
  #  @throws IOException on trouble launching the spawn
  
  def initialize(spawn, lDefaultTimeOutSeconds, echo)
    if lDefaultTimeOutSeconds < -1
      raise "Timeout must be >= -1, was " + lDefaultTimeOutSeconds
    end
    m_lDefaultTimeOutSeconds = lDefaultTimeOutSeconds;

    slave = SpawnableHelper.new(spawn, lDefaultTimeOutSeconds, echo);
    slave.start();
    log("Spawned Process: " + spawn);

    if (slave.getStdin() != null) 
      toStdin = BufferedWriter.new(OutputStreamWriter.new(slave.getStdin()));
    end

    stdoutSelector = Selector.open();
    slave.getStdoutChannel().register(stdoutSelector, SelectionKey.OP_READ);
    if (slave.getStderrChannel() != null) 
      stderrSelector = Selector.open();
      slave.getStderrChannel().register(stderrSelector, SelectionKey.OP_READ);
    end
  end

  ##
  #  This method is invoked by our {@link Timer} when the time-out occurs.
  
  def timerTimedOut() 
    continueReading = false;
    stdoutSelector.wakeup();
    if (stderrSelector != null) 
      stderrSelector.wakeup();
    end
    synchronized (doneWaitingForClose) {
      doneWaitingForClose.notify();
    }
  end

  ##
  #  This method is invoked by our {@link Timer} when the timer thread
  #  receives an interrupted exception
  #  @param reason The reason for the interrupt
  
  def timerInterrupted(reason) 
    timerTimedOut();
  end

  ##
  #  Wait for a pattern to appear on standard out.
  #  @param pattern The case-insensitive substring to match against.
  #  @param timeOutSeconds The timeout in seconds before the match fails.
  #  @throws IOException on IO trouble waiting for pattern
  #  @throws TimeoutException on timeout waiting for pattern
  
  def expect(pattern, timeOutSeconds)
    expect(pattern, timeOutSeconds, stdoutSelector);
  end

  ##
  #  Wait for the spawned process to finish.
  #  @param timeOutSeconds The number of seconds to wait before giving up, or
  #  -1 to wait forever.
  #  @throws ExpectJException if we're interrupted while waiting for the spawn
  #  to finish.
  #  @throws TimeoutException if the spawn didn't finish inside of the
  #  timeout.
  #  @see #expectClose()
  
  def expectClose(timeOutSeconds)
    if (timeOutSeconds < -1) 
      raise "Timeout must be >= -1, was " + timeOutSeconds
    end

    log("Waiting for spawn to close connection...");
    Timer tm = null;
    slave.setCloseListener(Spawnable.new.CloseListener() {
      def onClose()
        synchronized (doneWaitingForClose) {
          doneWaitingForClose.notify();
        }
      end
    });
    if (timeOutSeconds != -1 ) 
      tm = Timer.new(timeOutSeconds, TimerEventListener.new {
        def timerTimedOut() 
          Spawn.timerTimedOut();
        end

        def timerInterrupted(reason) 
          Spawn.timerInterrupted(reason);
        end
      });
      tm.startTimer();
    end
    continueReading = true;
    boolean closed = false;
    synchronized (doneWaitingForClose) {
      while(continueReading) 
        # Sleep if process is still running
        if (slave.isClosed()) 
          closed = true;
          break;
        else 
          begin
            doneWaitingForClose.wait(500);
          rescue
            raise "Interrupted waiting for spawn to finish"
          end
        end
      end
    }
    if (tm != null)
      tm.close();
    end
    if (closed)
      log("Connection to spawn closed, continueReading=" + continueReading)
    else 
      log("Timed out waiting for spawn to close, continueReading=" + continueReading)
    end
    if (tm != null) 
      log("Timer Status:" + tm.getStatus());
    end
    if (!continueReading)
      raise "Timeout waiting for spawn to finish"
    end

    freeResources();
  end

  ##
  #  Free up system resources.
  
  def freeResources() 
    begin
      slave.close();
      if (interactIn != null) 
        interactIn.stopProcessing();
      end
      if (interactOut != null) 
        interactOut.stopProcessing();
      end
      if (interactErr != null) 
        interactErr.stopProcessing();
      end
      if (stderrSelector != null) 
        stderrSelector.close();
      end
      if (stdoutSelector != null)
        stdoutSelector.close();
      end
      if (toStdin != null)
        toStdin.close();
      end
    rescue
      # Cleaning up is a best effort operation, failures are
      # logged but otherwise accepted.
      log("Failed cleaning up after spawn done");
    end
  end

  ##
  #  Wait the default timeout for the spawned process to finish.
  #  @throws ExpectJException If something fails.
  #  @throws TimeoutException if the spawn didn't finish inside of the default
  #  timeout.
  #  @see #expectClose(long)
  #  @see ExpectJ#ExpectJ(long)
  
  def expectClose()
    expectClose(m_lDefaultTimeOutSeconds);
  end

  ##
  #  Workhorse of the expect() and expectErr() methods.
  #  @see #expect(String, long)
  #  @param pattern What to look for
  #  @param lTimeOutSeconds How long to look before giving up
  #  @param selector A selector covering only the channel we should read from
  #  @throws IOException on IO trouble waiting for pattern
  #  @throws TimeoutException on timeout waiting for pattern
  
  def expect(pattern, lTimeOutSeconds, selector)
    if (lTimeOutSeconds < -1) 
      raise "Timeout must be >= -1, was " + lTimeOutSeconds
    end

    if (selector.keys().size() != 1) 
      raise "Selector key set size must be 1, was " + selector.keys().size()
    end
    # If this cast fails somebody gave us the wrong selector.
    readMe = (selector.keys().iterator().next()).channel();

    log("Expecting '" + pattern + "'");
    continueReading = true;
    boolean found = false;
    line = StringBuilder.new;
    runUntil = null;
    if (lTimeOutSeconds > 0) 
      runUntil = Date.new(Date.new.getTime() + lTimeOutSeconds);
    end
    buffer = ByteBuffer.allocate(1024);
    while(continueReading) 
      if (runUntil == null) 
        selector.select();
      else
        long msLeft = runUntil.getTime() - Date.new.getTime();
        if (msLeft > 0) 
          selector.select(msLeft);
        else
          continueReading = false;
          break;
        end
      end
      if (selector.selectedKeys().size() == 0)
        # Woke up with nothing selected, try again
        continue;
      end

      buffer.rewind();
      int readCount = readMe.read(buffer);
      if (readCount == -1) 
        # End of stream
        raise "End of stream reached, no match found"
      end
      buffer.rewind();
      line.append(String.new(buffer.array(), buffer.arrayOffset(), readCount, "ISO-8859-1"));
      if (line.toString().trim().toUpperCase().indexOf(pattern.toUpperCase()) != -1) 
        log("Found match for " + pattern + ":" + line);
        found = true;
        break;
      end
      while (line.indexOf("\n") != -1)
        line.delete(0, line.indexOf("\n") + 1);
      end
    end
    if (found)
      log("Match found, continueReading=" + continueReading)
    else
      log("Timed out waiting for match, continueReading=" + continueReading)
    end
    if (!continueReading)
      raise "Timeout trying to match \"" + pattern 
    end
  end

  ##
  #  Wait for a pattern to appear on standard out.
  #  @param pattern The case-insensitive substring to match against.
  #  @throws TimeoutException on timeout waiting for pattern
  #  @throws IOException on IO trouble waiting for pattern
  
  def expect(pattern)
    expect(pattern, m_lDefaultTimeOutSeconds);
  end


  ##
  #  This method can be use use to check the target process status
  #  before invoking {@link #send(String)}
  #  @return true if the process has already exited.
  
  def isClosed
    return slave.isClosed();
  end

  ##
  #  Retrieve the exit code of a finished process.
  #  @return the exit code of the process if the process has
  #  already exited.
  #  @throws ExpectJException if the spawn is still running.
  
  def getExitValue
    return slave.getExitValue();
  end

  ##
  #  Writes a string to the standard input of the spawned process.
  # 
  #  @param string The string to send.  Don't forget to terminate it with \n
  #  if you want it linefed.
  #  @throws IOException on IO trouble talking to spawn
  
  def send(string)
    log("Sending '" + string + "'");
    toStdin.write(string);
    toStdin.flush();
  end

  ##
  #  Allows the user to interact with the spawned process.
  
  def interact()
    # FIXME: User input is echoed twice on the screen
    interactIn = StreamPiper.new(null,
                   System.in, slave.getStdin());
    interactIn.start();
    interactOut = StreamPiper.new(null,
                    Channels.newInputStream(slave.getStdoutChannel()),
                    System.out);
    interactOut.start();
    interactErr = StreamPiper.new(null,
                    Channels.newInputStream(slave.getStderrChannel()),
                    System.err);
    interactErr.start();
    slave.stopPipingToStandardOut();
  end

  ##
  #  This method kills the process represented by SpawnedProcess object.
  
  def stop()
    slave.stop();

    freeResources();
  end

  ##
  #  Returns everything that has been received on the spawn's stdout during
  #  this session.
  # 
  #  @return the available contents of Standard Out
  
  def getCurrentStandardOutContents()
    return slave.getCurrentStandardOutContents();
  end

  ##
  #  Returns everything that has been received on the spawn's stderr during
  #  this session.
  # 
  #  @return the available contents of Standard Err
  
  def getCurrentStandardErrContents()
    return slave.getCurrentStandardErrContents();
  end
end
