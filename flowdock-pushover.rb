require 'rubygems'
require 'eventmachine'
require 'em-http'
require 'json'
require "net/https"

require './config'

def pushover(user, message)
  url = URI.parse("https://api.pushover.net/1/messages")
  req = Net::HTTP::Post.new(url.path)

  req.set_form_data({ :token => PUSHOVER[:token], :user => user, :message => message })
  res = Net::HTTP.new(url.host, url.port)
  res.use_ssl = true
  # res.verify_mode = OpenSSL::SSL::VERIFY_PEER
  res.start {|http| http.request(req) }
end

def flowdock(organization, flow)
  http = EM::HttpRequest.new("https://stream.flowdock.com/flows/#{organization}/#{flow}")
  EventMachine.run do
    s = http.get(:head => {
                   'Authorization' => [FLOWDOCK[:token], ''],
                   'accept' => 'application/json'
                 }, :keepalive => true, :connect_timeout => 0, :inactivity_timeout => 0)

    buffer = ""
    s.stream do |chunk|
      buffer << chunk
      while line = buffer.slice!(/.+\r\n/)
        puts JSON.parse(line).inspect
        item = JSON.parse(line)
        item['tags'].each do |user|
          po_token = USER_TOKENS[user]
          if po_token
            yield po_token, item['content']
          end
        end
      end
    end
  end
end

flowdock(FLOWDOCK[:org], FLOWDOCK[:flow]) { |user,m| pushover(user,m) }
