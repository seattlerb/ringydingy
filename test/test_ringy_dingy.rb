require 'test/unit'

$TESTING = true

require 'ringy_dingy'

class StubRingFinger

  attr_accessor :ring_server

  def initialize
    @ring_server = nil
  end

  def lookup_ring_any
    raise RuntimeError, 'RingNotFound' if @ring_server.nil?
    @ring_server
  end

end

class StubRingServer

  attr_accessor :tuples

  def initialize
    @tuples = []
  end

  def write(*args)
    @tuples << args
  end

  def read_all(template)
    @tuples.map { |t,r| t }.select { |t| t[1] == template[1] }
  end

end

class Rinda::SimpleRenewer

  attr_reader :sec

  def ==(other)
    self.class === other and sec == other.sec
  end

end

class TestRingyDingy < Test::Unit::TestCase

  def setup
    @identifier = "#{Socket.gethostname.downcase}_#{$PID}"
    @object = ""
    @ringy_dingy = RingyDingy.new @object

    @stub_ring_server = StubRingServer.new
    @ringy_dingy.ring_server = @stub_ring_server
  end

  def test_identifier
    assert_equal @identifier, @ringy_dingy.identifier

    @ringy_dingy = RingyDingy.new @object, nil, 'blah'

    assert_equal "#{@identifier}_blah", @ringy_dingy.identifier
  end

  def test_register
    @ringy_dingy.register

    expected = [
      [[:name, :RingyDingy, DRbObject.new(@object), @identifier],
       Rinda::SimpleRenewer.new]
    ]

    assert_equal expected, @stub_ring_server.tuples
  end

  def test_register_service
    @ringy_dingy = RingyDingy.new @object, :MyDRbService
    @ringy_dingy.ring_server = @stub_ring_server
    @ringy_dingy.register

    expected = [
      [[:name, :MyDRbService, DRbObject.new(@object), @identifier],
       Rinda::SimpleRenewer.new]
    ]

    assert_equal expected, @stub_ring_server.tuples
  end

  def test_registered_eh
    @stub_ring_server.tuples << [
      [:name, :RingyDingy, @object, @identifier], nil]

    assert_equal true, @ringy_dingy.registered?
  end

  def test_registered_eh_not_registered
    assert_equal false, @ringy_dingy.registered?
  end

  def test_registered_eh_no_ring_server
    def @stub_ring_server.read_all(*args)
      raise DRb::DRbConnError
    end

    assert_equal false, @ringy_dingy.registered?

    assert_equal nil, @ringy_dingy.instance_variable_get(:@ring_server)
  end

  def test_registered_eh_service
    @ringy_dingy = RingyDingy.new @object, :MyDRbService
    @ringy_dingy.ring_server = @stub_ring_server

    @stub_ring_server.tuples << [
      [:name, :MyDRbService, @object, @identifier], nil]

    assert_equal true, @ringy_dingy.registered?
  end

  def test_renewer
    assert_equal Rinda::SimpleRenewer.new, @ringy_dingy.renewer
  end

  def test_ring_server
    util_create_stub_ring_finger :server

    assert_equal :server, @ringy_dingy.ring_server
  end

  def test_ring_server_not_found
    util_create_stub_ring_finger

    assert_raise RuntimeError do @ringy_dingy.ring_server end
  end

  def test_stop
    @ringy_dingy.thread = Thread.start do sleep end
    assert_equal nil, @ringy_dingy.stop
  end

  def util_create_stub_ring_finger(rs = nil)
    @ringy_dingy.ring_server = nil

    ring_finger = StubRingFinger.new

    ring_finger.ring_server = rs unless rs.nil?

    @ringy_dingy.ring_finger = ring_finger
  end

end

