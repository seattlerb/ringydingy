require 'English'
require 'drb'
require 'rinda/ring'

$TESTING = false unless defined? $TESTING

##
# RingyDingy registers a DRb service with a Rinda::RingServer and re-registers
# the service if communication with the Rinda::RingServer is ever lost.
#
# Similarly, if the Rinda::RingServer should ever lose contact with the
# service the registration will be automatically dropped after a short
# timeout.
#
# = Example
#
#   my_service = MyService.new
#   rd = RingyDingy.new my_service, :MyService
#   rd.run
#   DRb.thread.join

class RingyDingy

  VERSION = '1.2.1'

  ##
  # Interval to check the RingServer for our registration information.

  attr_accessor :check_every

  ##
  # RingyDingy service identifier.  Use this to distinguish between
  # RingyDingys registering the same service.

  attr_reader :identifier

  ##
  # RingyDingy run loop thread.

  attr_reader :thread

  if $TESTING then
    attr_accessor :ring_finger, :renewer, :thread # :nodoc:
    attr_writer :ring_server # :nodoc:
  end

  ##
  # Creates a new RingyDingy that registers +object+ as +service+ with
  # optional identifier +name+.

  def initialize(object, service = :RingyDingy, name = nil)
    DRb.start_service unless DRb.primary_server

    @identifier = [Socket.gethostname.downcase, $PID, name].compact.join '_'
    @object = object
    @service = service || :RingyDingy

    @check_every = 180
    @renewer = Rinda::SimpleRenewer.new

    @ring_finger = Rinda::RingFinger.new
    @ring_server = nil

    @thread = nil
  end

  ##
  # Registers this service with the primary Rinda::RingServer.

  def register
    ring_server.write [:name, @service, DRbObject.new(@object), @identifier],
                      @renewer
    return nil
  end

  ##
  # Looks for a registration tuple in the primary Rinda::RingServer.  If a
  # RingServer can't be found or contacted, returns false.

  def registered?
    registrations = ring_server.read_all [:name, @service, nil, @identifier]
    registrations.any? { |registration| registration[2] == @object }
  rescue DRb::DRbConnError
    @ring_server = nil
    return false
  end

  ##
  # Looks up the primary Rinde::RingServer.

  def ring_server
    return @ring_server unless @ring_server.nil?
    @ring_server = @ring_finger.lookup_ring_any
  end

  ##
  # Starts a thread that checks for a registration tuple every #check_every
  # seconds.

  def run
    @thread = Thread.start do
      loop do
        begin
          register unless registered?
        rescue DRb::DRbConnError
          @ring_server = nil
        rescue RuntimeError => e
          raise unless e.message == 'RingNotFound'
        end
        sleep @check_every
      end
    end
  end

  ##
  # Stops checking for registration tuples.

  def stop
    @thread.kill
    return nil
  end

end

