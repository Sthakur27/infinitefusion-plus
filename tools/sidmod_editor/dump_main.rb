require_relative 'stub_loader'
require 'zlib'
s = StubLoader.load_file(File.join(__dir__, '..', '..', 'Data', 'Scripts.rxdata'))
main = s.find { |e| e[1].to_s == 'Main' }
puts Zlib::Inflate.inflate(main[2])
