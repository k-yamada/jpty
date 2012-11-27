include Java
java_import "java.io.IOException"
java_import "java.io.InputStream"
java_import "java.io.OutputStream"
java_import "java.io.PrintStream"

##
#  This class is responsible for piping the output of one stream to the
#  other. Optionally it also copies the content to standard out or
#  standard err.
# 
#  @author	Sachin Shekar Shetty
# /

class StreamPiper

  ##
  #  When data piping is paused, we just drop data from the input stream
  #  rather than copying it to the output stream.
  # 
  #  @return True if piping is paused.  False otherwise.
  # /
  def getPipingPaused() 
    self.synchronized do
      return @pipingPaused;
    end
  end

  ##
  #  @param copyStream Stream to copy the contents to before piping
  #  the data to another stream. When this parameter is nil, it does
  #  not copy the contents
  #  @param pi Input stream to read the data
  #  @param po Output stream to write the data
  # /
  def initialize(copyStream, pi, po) 
    if (pi == nil) 
      raise "Input stream must not be nil"
    end
    @inputStream = pi
    @outputStream = po
    @copyStream = copyStream
    @sCurrentOut = java.lang.StringBuffer.new
    # So that JVM does not wait for these threads
    # TODO comment out because error
    #self.setDaemon(true);
    #self.setName("ExpectJ Stream Piper");
  end

  ##
  #  This method is used to stop copying on to Standard out and err.
  #  This is used after interact.
  # /
  def stopPipingToStandardOut() 
    self.synchronized do
      @pipingPaused = true;
    end
  end

  ##
  #  This method is used to start copying on to Standard out and err.
  #  This is used after interact.
  # /
  def startPipingToStandardOut() 
    self.synchronized do
      @pipingPaused = false;
    end
  end

  ##
  #  This is used to stop the thread, after the process is killed
  # /
  def stopProcessing() 
    self.synchronized do
      continueProcessing = false;
    end
  end

  ##
  #  Should we keep doing our thing?
  # 
  #  @return True if we should keep piping data.  False if we should shut down.
  # /
  def getContinueProcessing()
    self.synchronized do
      return continueProcessing;
    end
  end

  ##
  #  @return the entire available contents read from the stream
  # /
  def getCurrentContents() 
    self.synchronized do
      return @sCurrentOut.toString();
    end
  end

  ##
  #  Thread method that reads from the stream and writes to the other.
  # /
  def start()
    Thread.new {
      buffer = byte.new[512];
      begin
        while(getContinueProcessing()) do
          bytes_read = @inputStream.read(buffer);
          if (bytes_read == -1) 
            @inputStream.close();
            @outputStream.close();
            return;
          end
          self.synchronized do
            @sCurrentOut.append(new String(buffer, 0, bytes_read));
          end
          @outputStream.write(buffer, 0, bytes_read);
          if (@copyStream != nil && !getPipingPaused()) 
            @copyStream.write(buffer, 0, bytes_read);
            @copyStream.flush();
          end
          @outputStream.flush();
        end
      rescue
        if getContinueProcessing()
          puts "Trouble while pushing data between streams"
        end
      end
    }
  end

end
