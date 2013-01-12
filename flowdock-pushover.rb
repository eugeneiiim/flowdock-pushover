require 'rubygems'
require 'eventmachine'
require 'em-http'
require 'json'
require "net/https"
require "em-eventsource"

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
  EM.run do
    url = "https://stream.flowdock.com/flows/#{organization}/#{flow}"
    headers = {
      :accept => 'text/event-stream',
      'Authorization' => [ENV['FLOWDOCK_TOKEN'], '']
    }

    source = EventMachine::EventSource.new(url, nil, headers)

    source.message do |message|
      puts "new message #{message}"
      STDOUT.flush

      item = JSON.parse(message)

      item['tags'].each do |user|
        po_token = ENV['USER_TOKEN']
        if po_token
          puts "Push to (#{user}, #{po_token})"
          yield po_token, item['content']
        end
      end
    end

    source.open do
      puts "** Stream open"
      STDOUT.flush
    end

    source.error do |error|
      puts "** error #{error}"
      STDOUT.flush
    end

    source.start # Start listening
  end
end

t = Thread.new do
  loop do
    sleep 6 * 60 * 60
    exit
  end
end

flowdock(ENV['FLOWDOCK_ORG'], ENV['FLOWDOCK_FLOW']) { |user,m| pushover(user,m) }

puts 'flowdock returned'
t.join
