require 'plist'
require 'base64'
require 'socket'
require 'json'
require 'net/http'

class Rubyconf
  VERSION = '1.0.0'

  class WirelessNetwork
    def initialize(data)
      @data = data
    end

    def bssid
      @data["BSSID"]
    end

    def channel
      @data["CHANNEL"]
    end

    def ssid
      @ssid ||= @data["SSID"].string
    end

    def noise
      @data["NOISE"]
    end

    def rssi
      @data["RSSI"]
    end

    def show
      printf "%20s %4s %d\n", ssid, rssi, channel
    end
  end

  def refresh_wireless(xml=nil)
    xml ||= `airport -x -s`

    out = Plist.parse_xml xml

    @networks = out.map { |w| WirelessNetwork.new(w) }
  end

  def show_networks(filter=/./)
    printf "%20s %4s %s\n", "SSID", "RSSI", "CHANNEL"
    @networks.each do |n|
      if n.ssid =~ filter
        n.show
      end
    end
  end

  class CurrentNetwork
    def initialize(data)
      @data = data
    end

    def external
      {
        'ssid'  => @data['SSID'],
        'bssid' => @data['BSSID'],
        'rssi'  => @data['agrCtlRSSI'].to_i,
        'noise' => @data['agrCtlNoise'].to_i,
        'channel' => @data['channel'].to_i,
        'txrate' => @data['lastTxRate'].to_i,
        'maxrate' => @data['maxRate'].to_i
      }
    end
  end

  def current_network
    data = `airport -I`

    vals = data.split("\n").map { |x| x.split(":", 2).map { |i| i.strip } }

    CurrentNetwork.new Hash[*vals.flatten]
  end

  def ttg
    s = TCPSocket.new "74.125.224.134", 80
    start = Time.now
    s << "GET / HTTP/1.0\r\n\r\n"
    s.read(4)
    fin = Time.now
    s.close

    (fin - start) * 1_000_000
  end

  def post!
    data = current_network.external

    data['ttg'] = ttg

    Net::HTTP.start "rubyconf-wireless.herokuapp.com", 80 do |http|
      r = http.post "/sampler", JSON.dump(data)
      if r.code != "200"
        puts "Error posting results: #{r.inspect}"
        if $DEBUG
          puts r.body
        end
      end
    end
  end
end
