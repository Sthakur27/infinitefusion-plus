# Construct STRONG hazard-control mons the pool is missing, and validate every one
# against the engine before proposing it.
#
#   ruby tools/sidmod_editor/sim/nbuild_utility.rb [out_spec.json]
#
# Why construct rather than only edit: the mons that can have Defog added by editing all
# rate between -0.07 and -0.36, and the search selects on strength — weak utility mons
# would still never be picked. These are built to be genuinely good, so hazard control
# competes on merit.
#
# Each design is checked for: fusion validity (the silent Pikachu fallback), resulting
# typing and stats, ability legality, and that every move is in the head u body movepool.
require_relative 'nstore'
require_relative 'fusion_inspector'
require_relative 'editor'
SimEngine.boot
$DEBUG = false

OUT = ARGV[0] || File.join(NStore.dir('ou3'), 'utility_adds_spec.json')

# head gives type1/HP/SpA/SpD, body gives type2/Atk/Def/Spe (see fusion convention)
DESIGNS = [
  { nick: 'Defogscor', head: 'GLISCOR', body: 'SKARMORY', ability: 'POISONHEAL',
    item: 'TOXICORB', nature: 'IMPISH', role: 'Ground/Steel Poison Heal hazard controller',
    moves: %w[DEFOG STEALTHROCK ROOST KNOCKOFF],
    evs: { 'HP' => 252, 'DEFENSE' => 252, 'SPECIAL_DEFENSE' => 4 } },

  { nick: 'Zapmory', head: 'ZAPDOS', body: 'SKARMORY', ability: 'PRESSURE',
    item: 'LEFTOVERS', nature: 'BOLD', role: 'Electric/Steel Defog + VoltTurn momentum',
    moves: %w[DEFOG ROOST VOLTSWITCH THUNDERBOLT],
    evs: { 'HP' => 252, 'DEFENSE' => 252, 'SPECIAL_ATTACK' => 4 } },

  { nick: 'Spikemory', head: 'SKARMORY', body: 'DRAGONITE', ability: 'MULTISCALE',
    item: 'LEFTOVERS', nature: 'IMPISH', role: 'Multiscale Spikes stacker + Defog',
    moves: %w[SPIKES DEFOG ROOST BRAVEBIRD],
    evs: { 'HP' => 252, 'DEFENSE' => 252, 'ATTACK' => 4 } },

  { nick: 'Spinress', head: 'FORRETRESS', body: 'SCIZOR', ability: 'STURDY',
    item: 'LEFTOVERS', nature: 'RELAXED', role: 'Bug/Steel Rapid Spin + full hazard set',
    moves: %w[RAPIDSPIN STEALTHROCK SPIKES GYROBALL],
    evs: { 'HP' => 252, 'DEFENSE' => 252, 'ATTACK' => 4 } },

  { nick: 'Sandzor', head: 'SANDSLASH', body: 'SCIZOR', ability: 'TECHNICIAN',
    item: 'LEFTOVERS', nature: 'IMPISH', role: 'Ground/Steel spinner + rocks',
    moves: %w[RAPIDSPIN STEALTHROCK EARTHQUAKE KNOCKOFF],
    evs: { 'HP' => 252, 'DEFENSE' => 252, 'ATTACK' => 4 } },

  { nick: 'Torkozor', head: 'TORKOAL', body: 'SCIZOR', ability: 'DROUGHT',
    item: 'LEFTOVERS', nature: 'RELAXED', role: 'Drought setter that also spins hazards away',
    moves: %w[RAPIDSPIN STEALTHROCK LAVAPLUME KNOCKOFF],
    evs: { 'HP' => 252, 'DEFENSE' => 252, 'SPECIAL_ATTACK' => 4 } },

  { nick: 'Guardrock', head: 'CLEFABLE', body: 'BLISSEY', ability: 'MAGICGUARD',
    item: 'LEFTOVERS', nature: 'CALM', role: 'Magic Guard rocker, immune to hazard/status chip',
    moves: %w[STEALTHROCK SOFTBOILED MOONBLAST KNOCKOFF],
    evs: { 'HP' => 252, 'SPECIAL_DEFENSE' => 252, 'DEFENSE' => 4 } },

  { nick: 'Starsteel', head: 'STARMIE', body: 'REGISTEEL', ability: 'NATURALCURE',
    item: 'LEFTOVERS', nature: 'BOLD', role: 'Water/Steel spinner with recovery',
    moves: %w[RAPIDSPIN RECOVER SCALD STEALTHROCK],
    evs: { 'HP' => 252, 'DEFENSE' => 252, 'SPECIAL_ATTACK' => 4 } },

  { nick: 'Toxispin', head: 'TENTACRUEL', body: 'FORRETRESS', ability: 'STURDY',
    item: 'BLACKSLUDGE', nature: 'BOLD', role: 'Toxic Spikes + Rapid Spin',
    moves: %w[TOXICSPIKES RAPIDSPIN SCALD KNOCKOFF],
    evs: { 'HP' => 252, 'DEFENSE' => 252, 'SPECIAL_DEFENSE' => 4 } },

  { nick: 'Cradrock', head: 'CRADILY', body: 'FERROTHORN', ability: 'IRONBARBS',
    item: 'LEFTOVERS', nature: 'CAREFUL', role: 'Rock/Grass rocks + recovery, Suction-proof',
    moves: %w[STEALTHROCK RECOVER KNOCKOFF POWERWHIP],
    evs: { 'HP' => 252, 'SPECIAL_DEFENSE' => 252, 'DEFENSE' => 4 } },
]

def movepool(*bases)
  s = []
  bases.each do |b|
    sp = (GameData::Species.get(b.to_sym) rescue nil) or next
    (sp.moves rescue []).each { |m| s << (m.is_a?(Array) ? m[1] : m) }
    (sp.tutor_moves rescue []).each { |m| s << m }
    (sp.egg_moves rescue []).each { |m| s << m }
  end
  s.compact.map { |m| m.to_s.to_sym }.uniq
end

ok_designs = []
puts "VALIDATING #{DESIGNS.length} CONSTRUCTED UTILITY MONS"
puts "=" * 100
DESIGNS.each do |d|
  problems = []
  %w[head body].each do |part|
    sym = d[part.to_sym].to_sym
    problems << "#{part} #{sym} INVALID (silent Pikachu fallback?)" unless Editor.valid_species?(sym)
  end
  mp = movepool(d[:head], d[:body])
  missing = d[:moves].map(&:to_sym) - mp
  problems << "moves not in head+body pool: #{missing.join(',')}" if missing.any?
  item_ok = (GameData::Item.exists?(d[:item].to_sym) rescue false)
  problems << "item #{d[:item]} does not exist" unless item_ok

  res = begin
    Inspect.check('head' => d[:head], 'body' => d[:body], 'ability' => d[:ability],
                  'item' => d[:item], 'nature' => d[:nature], 'moves' => d[:moves],
                  'evs' => d[:evs])
  rescue => e
    problems << "inspector error: #{e.class} #{e.message[0, 60]}"
    nil
  end

  if res
    stats = res[:stats] || res['stats']
    types = res[:types] || res['types']
    ab    = res[:ability] || res['ability']
    flags = (res[:flags] || res['flags'] || [])
    problems << "ability resolved to #{ab} not #{d[:ability]}" if ab && ab.to_s.upcase.delete('^A-Z') !=
                                                                  d[:ability].to_s.upcase.delete('^A-Z')
    puts "\n#{d[:nick]}  #{d[:head]}/#{d[:body]}"
    puts "  role     #{d[:role]}"
    puts "  types    #{types.is_a?(Array) ? types.join('/') : types}    ability #{ab}    item #{d[:item]}"
    puts "  stats    #{stats.is_a?(Hash) ? stats.map { |k, v| "#{k}#{v}" }.join(' ') : stats.inspect}"
    puts "  moves    #{d[:moves].join(' / ')}"
    puts "  flags    #{flags.empty? ? 'none' : flags.join(', ')}"
  end
  if problems.empty?
    puts "  VALID"
    ok_designs << d
  else
    puts "  PROBLEMS: #{problems.join(' | ')}"
  end
end

puts "\n#{ok_designs.length}/#{DESIGNS.length} designs validated"
spec = { 'pokemon' => ok_designs.map { |d|
  { 'mode' => 'add', 'box' => nil, 'head' => d[:head], 'body' => d[:body],
    'nickname' => d[:nick], 'level' => 100, 'ability' => d[:ability], 'item' => d[:item],
    'nature' => d[:nature], 'moves' => d[:moves], 'evs' => d[:evs],
    'ivs' => { 'HP' => 31, 'ATTACK' => 31, 'DEFENSE' => 31, 'SPECIAL_ATTACK' => 31,
               'SPECIAL_DEFENSE' => 31, 'SPEED' => 31 } } } }
File.binwrite(OUT, NStore::GEN.call(spec))
puts "spec (box still to be set) -> #{OUT}"
