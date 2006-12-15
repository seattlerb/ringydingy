require 'hoe'

require './lib/ringy_dingy.rb'

Hoe.new 'RingyDingy', RingyDingy::VERSION do |p|
  p.summary = 'RingyDingy is a little boat that keeps your DRb service afloat!'
  p.description = 'RingyDingy automatically re-registers your DRb service with a RingServer should communication with the RingServer stop.'
  p.url = 'http://seattlerb.rubyforge.org/RingyDingy'
  p.author = 'Eric Hodel'
  p.email = 'drbrain@segment7.net'
  p.rubyforge_name = 'seattlerb'
  p.changes = File.read('History.txt').scan(/\A(=.*?)(=|\Z)/m).first.first

  p.extra_deps << ['ZenTest', '>= 3.4.0']
end

# vim: syntax=Ruby
