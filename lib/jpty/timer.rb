##
#  This class acts like a timer and invokes the listener on time-out.
#  
class Timer 
  include java.lang.Runnable

  ##
  #  Timer not started.
  #  
  NOT_STARTED = 0;

  ##
  #  Timer started and still running.
  #  
  STARTED   = 1;

  ##
  #  Timer timed out.
  #  
  TIMEDOUT  = 2;

  ##
  #  Timer interrupted.
  #  
  INTERRUPTED = 3;

  ##
  #  Constructor
  # 
  #  @param timeOut  Time interval after which the listener will be
  #          invoked
  #  @param listener Object implementing the TimerEventListener
  #          interface
  #  
  def initialize(timeOut, listener)

    if (timeOut < 1) 
      raise "Time-Out value cannot be < 1"
    end
    if (listener == nil )
      raise "Listener cannot be nil"
    end
    @timeOut = timeOut #  1000;
    @listener = listener
    # Are we there yet?
    @done = false
  end

  ##
  #  Starts the timer
  #  
  def startTimer() 
    Thread.start {
      run
    }
    @currentStatus = STARTED;
  end

  ##
  #  Return timer status.  Can be one of {@link #NOT_STARTED}, {@link #STARTED},
  #  {@link #TIMEDOUT} or {@link #INTERRUPTED}.
  # 
  #  @return the status of the timer
  #  
  def getStatus()
    @currentStatus;
  end

  ##
  #  Close the timer prematurely.  The event listener won't get any
  #  notifications.
  #  
  def close()
    self.synchronized do
      @done = true;
      self.notify();
    end
  end

  ##
  #  This is the timer thread main.
  #  
  def run()
    begin
      # Sleep for the specified time
      self.synchronized do
        wait(timeOut);
        if (@done) 
          # We've been nicely asked to quit
          return
        end

        # Jag Utha Shaitan, Its time to invoke the listener
        @currentStatus = TIMEDOUT;
        @listener.timerTimedOut();
      end
    rescue
      @currentStatus = INTERRUPTED;
      @listener.timerInterrupted(iexp);
    end
  end

end
