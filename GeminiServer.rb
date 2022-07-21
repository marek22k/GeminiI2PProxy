
# This is a modified GeminiServer from
# https://rubygems.org/gems/bgeminiserver

require "socket"
require "openssl"

class GeminiServer
  
  attr_accessor :universal_handler
  
  def initialize cert, key
    @context = OpenSSL::SSL::SSLContext.new
    # Require min tls version (spec 4.1)
    @context.min_version = :TLS1_2
    @context.add_certificate cert, key
    # Enable client certificates (spec 4.3)
    @context.verify_mode = OpenSSL::SSL::VERIFY_PEER
    # Ignore invalid (e. g. self-signed) certificates
    @context.verify_callback = ->(passed, cert) { return true }
  end
  
  def start host = "localhost", port = 1965
    serv = TCPServer.new host, port
    @secure = OpenSSL::SSL::SSLServer.new(serv, @context)
    
    return self
  end
  
  def listen log = false
    puts "Listen..."
    loop do
      begin
        Thread.new(@secure.accept) do |conn|
          begin
            request_line = conn.gets
            
            @universal_handler.(conn, conn.peer_cert, request_line)
            
            conn.flush
            conn.close
          rescue
            $stderr.puts $!
          end
        end
      rescue
        $stderr.puts $!
      end
    end
  end
  
end