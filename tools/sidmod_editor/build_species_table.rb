# Reads Data/species.dat → species_table.json keyed by dex number.
# Offline base data for fusion stat/type/ability/exp computation + move legality.
require_relative 'stub_loader'
require 'json'

SPECIES_DAT = ARGV[0] || File.join(__dir__, '..', '..', 'Data', 'species.dat')
OUT = ARGV[1] || File.join(__dir__, 'species_table.json')

data = StubLoader.load_file(SPECIES_DAT)
table = {}
data.each do |k, rec|
  next unless k.is_a?(Integer)          # integer keys = dex numbers (symbol keys are dupes)
  next unless rec.instance_variable_get(:@form).to_i == 0   # base form only
  g = ->(iv) { rec.instance_variable_get(iv) }
  table[k] = {
    "id"            => g.(:@id).to_s,
    "name"          => g.(:@real_name),
    "base_stats"    => g.(:@base_stats),
    "type1"         => g.(:@type1),
    "type2"         => g.(:@type2),
    "abilities"     => g.(:@abilities),
    "hidden"        => g.(:@hidden_abilities),
    "growth_rate"   => g.(:@growth_rate).to_s,
    "gender_ratio"  => g.(:@gender_ratio).to_s,
    "happiness"     => g.(:@happiness),
    "levelup_moves" => (g.(:@moves) || []).map { |pair| [pair[0], pair[1].to_s] },
    "egg_moves"     => (g.(:@egg_moves) || []).map(&:to_s),
    "tutor_moves"   => (g.(:@tutor_moves) || []).map(&:to_s),
  }
end
File.write(OUT, JSON.generate(table))
warn "wrote #{table.size} species to #{OUT}"
warn "sanity: dex1=#{table[1]&.dig('name')} dex151=#{table[151]&.dig('name')} dex501=#{table[501]&.dig('name')}"
