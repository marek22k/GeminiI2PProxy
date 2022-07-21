
# Copyright 2022 Marek Küthe
# GNU GPLv3

# Source: https://github.com/marek22k/samapi/blob/main/lib/samapi.rb
# or
# Source: https://codeberg.org/mark22k/samapi/src/branch/main/lib/samapi.rb

require "socket"
require "io/wait"

# Documentation about the SAM API can be found at https://geti2p.net/en/docs/api/samv3.
# This class is just my attempt to build it into Ruby as a kind of wrapper.

class SamApi
  
  # Creates a SAM command based on the first command, the second command, and
  # the arguments
  #
  # @param first [String, Symbol]
  # @param second [String, Symbol]
  # @param args [Hash]
  # @return [String]
  # @example
  #   SamApi.create_command :hello, :version, { "MIN" => "3.0" }  # => "HELLO VERSION MIN=3.0"
  def self.create_command first, second = nil, args = {}
    cmd = "#{first.to_s.upcase}"
    cmd += " #{second.to_s.upcase}" if second
    args.each_pair { |key, value|
      if key && value
        value = value.to_s
        value = value.include?(" ") ? "\"#{value}\"" : value
        cmd += " #{key.to_s}=#{value}"
      end
    }
    return cmd
  end
  
  # Extracts the first and second command and arguments from a SAM command and
  # returns them as a hash.
  #
  # @param cmd [String]
  # @return [Hash]
  # @example
  #   SamApi.parse_command "HELLO REPLY RESULT=OK VERSION=3.3"  # => {:first=>"HELLO", :second=>"REPLY", :args=>{:result=>"OK", :version=>"3.3"}}
  def self.parse_command cmd
    parsed = cmd.scan(/(?:\"(.*?)\")|([^" =]+)/).map { |arr|
      arr.compact[0]
    }
    # thanks to https://stackoverflow.com/questions/71010013/regex-does-not-return-all-the-argument
    first = parsed[0]
    second = parsed[1]
    args = {}
    
    for i in (2...parsed.length).step 2
      args[parsed[i].downcase.to_sym] = parsed[i + 1]
    end
    
    return {first: first, second: second, args: args}
  end
  
  attr_reader :version
  attr_accessor :socket
  
  # Initializes a SAM session but does not shake hands (HELLO VERSION)
  #
  # @param _host [String] Host on which the SAM Server is running.
  # @param _port [Integer] Port on which the SAM Server is running.
  def initialize host: "127.0.0.1", port: 7656
    @host = host
    @port = port
    @socket = TCPSocket.new @host, @port
  end
  
  # Checks whether there is still a connection to the SAM server.
  #
  # @return [TrueClass, FalseClass] true if there is still a connection, otherwise false
  def is_open?
    return ! @socket.closed?
  end
  
  # Sends a command directly to the SAM server and returns an evaluated response.
  #
  # @param first [String, Symbol] see SamApi.create_command
  # @param second [String, Symbol] see SamApi.create_command
  # @param args [Hash] see SamApi.create_command
  # @return [Hash] see SamApi.parse_command
  def send_cmd first, second, args
    cmd = SamApi.create_command first, second, args
    @socket.puts cmd
    ans = @socket.gets.chomp
    ans_parsed = SamApi.parse_command ans
    
    return ans_parsed
  end
   
  # It can happen that the SAM server sends a ping. The client is instructed to
  # respond with a pong. This function checks whether the server requests a pong
  # and sends one if it does. This should always be called up when you are not
  # actively communicating with the SAM server.
  def check_ping
    if @socket.ready? && @socket.ready? != 0 && ! @socket.closed?
      ans = @socket.gets.chomp.split " "
      cmd = ans[0].downcase
      arg = ans[1]
      if cmd == "ping"
        @socket.puts "PONG #{arg}"
      end
    end
  end
  
  def send_ping _test = nil
    test = _test
    test = Time.now.to_i.to_s if ! test
    @socket.puts "PING #{test}"
    ans = @socket.gets.chomp.split " "
    cmd = ans[0].downcase
    arg = ans[1]
    return cmd == "pong" && arg == test
  end
  
  # Performs a HELLO VERSION handshake with the SAM server.
  #
  # @param args [Hash] could min, max, user and password
  # @return [Array] The first element contains either true or false depending on
  # whether the handshake was successful. The second element contains the
  # evaluated answer.
  def handshake args = {}
    ans = send_cmd :hello, :version, args
    @version = ans[:args][:version]
    status = ans[:args][:result] == "OK"
    return [status, ans]
  end
  
  def session_create args = {}
    ans = send_cmd :session, :create, args
    priv_key = ans[:args][:destination]
    status = ans[:args][:result] == "OK"
    return [status, priv_key, ans]
  end
  
  def session_add args = {}
    ans = send_cmd :session, :add, args
    priv_key = ans[:args][:destination]
    status = ans[:args][:result] == "OK"
    return [status, priv_key, ans]
  end
  
  def session_remove args = {}
    ans = send_cmd :session, :remove, args
    status = ans[:args][:result] == "OK"
    return [status, ans]
  end
  
  def stream_connect args = {}, check = true
    ans = send_cmd :stream, :connect, args
    status = check ? ans[:args][:result] == "OK" : nil
    return [status, @socket, ans]
  end
  
  def stream_accept args = {}
    ans = send_cmd :stream, :accept, args
    status = ans[:args][:result] == "OK"
    return [status, @socket, ans]
  end
  
  def stream_forward args = {}
    ans = send_cmd :stream, :forward, args
    status = ans[:args][:result] == "OK"
    return [status, ans]
  end
  
  def naming_lookup name
    ans = send_cmd :naming, :lookup, { "NAME" => name }
    status = ans[:args][:result] == "OK"
    name = ans[:args][:name]
    return [status, name, ans]
  end
  
  def dest_generate args
    ans = send_cmd :dest, :generate, args
    pub_key = ans[:args][:pub]
    priv_key = ans[:args][:priv]
    return [pub_key, priv_key]
  end
  
  # Closes the connection to the SAM server
  def close cmd = "QUIT"
    @socket.puts cmd
    @socket.close if ! @socket.closed?
  end
  
end
