
require_relative "GeminiServer"
require_relative "samapi"
require_relative "GeminiProxy"

require "openssl"

proxy = GeminiProxy.new

# Hello!
# This is a simple proxy program for Lagrange Gemini Browser
# You can test it with my selfhosted egsam test:
# liuvghhyoyu2m7hdue267y4a4ch2tecbqh6pgbqyjheniuybu2vq.b32.i2p

# If you do not change the parameters below,
# you can point the proxy
# (File -> Preferences... -> Network -> Proxies -> Gemini Proxy)
# to localhost:8882

# To use this proxy, you have to enable the SAM API in the Router Console
# or in case if i2pd in the config file

# You have to trust the certificate of the proxy to use it
# Every restart it creates a new key and a new certificate
# (RSA 4096, SHA512)

# Client certificates do not working

# If you find errors / bug / mistakes, feel free to report it on
# GitHub or Codeberg

###   PARAMETERS   ###
proxy.host = "localhost"
proxy.port = 8882
proxy.sam_host = "127.0.0.1"
proxy.sam_port = 7656
proxy.samid = "GeminiProxy"
proxy.sam_signature = "EdDSA_SHA512_Ed25519"
proxy.sam_inbound_len = "3"
proxy.sam_outbound_len = "3"
proxy.sam_inbound_quantity = "2"
proxy.sam_outbound_quantity = "2"
proxy.sam_inbound_backup_quantity = "1"
proxy.sam_outbound_backup_quantity = "1"
proxy.rsa_size = 4096

### PARAMETERS END ###

proxy.setup_all
proxy.start