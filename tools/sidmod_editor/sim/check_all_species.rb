# Validate EVERY species across all teams in a tag's field - catches silent fallbacks
# (unknown name -> PIKACHU). ruby check_all_species.rb [tag]
require 'json'
TAG = ARGV[0] || 'round3'
# Parse BEFORE booting: the engine redefines JSON.parse to a broken version during boot.
field = JSON.parse(File.read(File.join(__dir__, 'reports', TAG, 'field_specs.json')))
require_relative 'build_team'
require_relative 'editor'
SimEngine.boot
$DEBUG = false

bad = []
total = 0
field.each do |name, team|
  team.each do |m|
    %w[head body species].each do |k|
      sp = m[k]
      next unless sp && !sp.to_s.empty?
      total += 1
      sym = sp.to_s.upcase.gsub(/[^A-Z0-9]/, '').to_sym
      unless Editor.valid_species?(sym)
        r = (GameData::Species.get(sym) rescue nil)
        bad << "#{name}: '#{sp}' -> resolves to #{r ? r.id : 'nil'} (NOT itself)"
      end
    end
  end
end
puts "checked #{total} species across #{field.size} teams in '#{TAG}'"
if bad.empty?
  puts "ALL VALID - no silent fallbacks."
else
  puts "#{bad.length} INVALID:"
  bad.each { |b| puts "  !! #{b}" }
end
