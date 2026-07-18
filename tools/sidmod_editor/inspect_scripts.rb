require_relative 'stub_loader'
require 'zlib'
s = StubLoader.load_file(File.join(__dir__, '..', '..', 'Data', 'Scripts.rxdata'))
puts "top: #{s.class}, entries: #{s.size rescue '?'}"
if s.is_a?(Array)
  puts "first entry shape: #{s[0].class} len #{s[0].size rescue '?'}"
  # RMXP format: [magic_id, name, Zlib-deflated code]
  names = s.map { |e| e[1].to_s }
  puts "sample names: #{names.first(6).inspect}"
  puts "battle-ish scripts: #{names.select { |n| n =~ /battle|move|damage|AI/i }.first(12).inspect}"
  code0 = Zlib::Inflate.inflate(s[0][2]) rescue "(inflate failed)"
  puts "\nfirst script inflates to #{code0.bytesize} bytes; head:"
  puts code0[0,160]
  total = s.sum { |e| (Zlib::Inflate.inflate(e[2]).bytesize rescue 0) }
  puts "\ntotal inflated source: #{(total/1024.0/1024).round(2)} MB across #{s.size} scripts"
  # how many reference RGSS/graphics at all (rough shim-surface gauge)
  gfx = s.count { |e| (Zlib::Inflate.inflate(e[2]) =~ /\b(Graphics|Sprite|Viewport|Bitmap|Input|Audio|Win32API)\b/ rescue false) }
  puts "scripts referencing RGSS/graphics symbols anywhere: #{gfx}/#{s.size}"
end
