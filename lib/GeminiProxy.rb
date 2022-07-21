
require "uri"

class SamException < RuntimeError
  def initialize msg = "Generic sam error"
    super msg
  end
end

class GeminiProxy
  
  attr_accessor :samid,
                :host,
                :port,
                :sam_host,
                :sam_port,
                :rsa_size,
                :sam_signature,
                :sam_inbound_len,
                :sam_outbound_len,
                :sam_inbound_quantity,
                :sam_outbound_quantity,
                :sam_inbound_backup_quantity,
                :sam_outbound_backup_quantity
              
  attr_reader :sam_version
  
  def setup_all
    setup_sam
    setup_server
    setup_handler
  end
  
  def setup_sam
    control = SamApi.new host: @sam_host, port: @sam_port
    status = control.handshake
    if status[0]
      puts "Handshake complete!"
    else
      raise SamException.new("Handshake failed!")
    end
    @sam_version = control.version
    
    status = control.session_create(
      "STYLE" => "STREAM",
      "ID" => @samid,
      "DESTINATION" => "TRANSIENT",
      "SIGNATURE_TYPE" => @sam_signature,
      "inbound.length" => @sam_inbound_len,
      "outbound.length" => @sam_outbound_len,
      "inbound.quantity" => @sam_inbound_quantity,
      "outbound.quantity" => @sam_outbound_quantity,
      "inbound.backupQuantity" => @sam_inbound_backup_quantity,
      "outbound.backupQuantity" => @sam_outbound_backup_quantity
    )

    if status[0]
      puts "Session created!"
    else
      raise SamException.new("Session creation failed!")
    end

    Thread.new {
      loop {
        control.check_ping
        status = control.send_ping
        if ! status
          puts "Warning = No ping"
        end
        sleep 10
      }
    }
  end
  
  def setup_server
    cert = OpenSSL::X509::Certificate.new
    key  = OpenSSL::PKey::RSA.generate rsa_size

    cert = OpenSSL::X509::Certificate.new

    cert.version = 2
    cert.serial = 1

    subject = OpenSSL::X509::Name.new [
      ["CN", "localhost"],
      ["O", "Local gemini proxy for I2P"],
      ["emailAddress", "webmaster@localhost"]
    ]
    cert.subject = subject
    cert.issuer = cert.subject
    cert.public_key = key.public_key

    cert.not_before = Time.now
    cert.not_after = cert.not_before + 30 * 24 * 60 * 60 # 1 month validity

    ef = OpenSSL::X509::ExtensionFactory.new
    ef.subject_certificate = cert
    ef.issuer_certificate = cert
    cert.add_extension(ef.create_extension("keyUsage","digitalSignature", true))
    cert.add_extension(ef.create_extension("subjectKeyIdentifier", "hash", false))
    cert.sign(key, OpenSSL::Digest::SHA512.new)

    @serv = GeminiServer.new cert, key
  end
  
  def setup_handler
    @serv.universal_handler = ->(conn, cert, request) {
      uri = URI(request.chomp)
      if uri.host == "status"
        conn.print "20 text/gemini\r\n"
        conn.print "# Proxy status\r\n"
        conn.print "The proxy works!\r\n"
        conn.print "SAM API: #{@sam_version}\r\n"
        return
      end

      begin
        puts "Receive request..."
        comm = SamApi.new host: @sam_host, port: @sam_port
        comm.handshake
        puts "Connected to sam api"

        puts "Connecting to #{uri.host}..."
        stream = comm.stream_connect(
          "ID" => @samid,
          "DESTINATION" => uri.host
        )

        if stream[0]
          puts "Connected to #{uri.host}!"
        else
          conn.print "53 Failed to connect to #{uri.host}\r\n"
          return
        end

        puts "Receive socket..."
        socket = stream[1]
        context = OpenSSL::SSL::SSLContext.new
        context.min_version = :TLS1_2
        puts "Open TLS connection"
        secure = OpenSSL::SSL::SSLSocket.new socket, context
        secure.sync_close = true
        secure.connect

        puts "Request resouce from #{uri.host}..."
        secure.print request
        puts "Forward answer..."
        IO::copy_stream(secure, conn)

        secure.close
      rescue StandardError => e
        conn.print "53 #{e.to_s}\r\n"
      end
    }
  end
  
  def start
    @serv.start @host, @port
    @serv.listen
  end
  
end