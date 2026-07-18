# Offline save writer.  ruby edit_save.rb <in.rxdata> <spec.json> <out.rxdata>
# Template-clones a real Pokemon, applies the spec, computes stats, self-validates,
# and inserts into the target box. Writes <out> only if EVERY mon validates.
require_relative 'stub_loader'
require_relative 'pokemath'
require 'json'
require 'set'

IN, SPEC_PATH, OUT = ARGV[0], ARGV[1], ARGV[2]
DIR = __dir__
NB = 501

def norm(s) s.to_s.upcase.gsub(/[^A-Z0-9]/, "") end
def ivg(o, n) o.instance_variable_get(n) end
def ivs(o, n, v) o.instance_variable_set(n, v) end
def clone(o) Marshal.load(Marshal.dump(o)) end

# ---- load data ----
save   = StubLoader.load_file(IN)
spec   = JSON.parse(File.read(SPEC_PATH))
TABLE  = JSON.parse(File.read(File.join(DIR, 'species_table.json')))
MOVES  = JSON.parse(File.read(File.join(DIR, 'moves_table.json')))
ABILITY_SET = begin; StubLoader.load_file(File.join(DIR, '..', '..', 'Data', 'abilities.dat')).keys.select { |k| k.is_a?(Symbol) }.map { |k| k.to_s }.to_set; rescue; nil; end
ITEM_SET    = begin; StubLoader.load_file(File.join(DIR, '..', '..', 'Data', 'items.dat')).keys.select { |k| k.is_a?(Symbol) }.map { |k| k.to_s }.to_set; rescue; nil; end

BY_NORMID = {}; BY_NAME = {}
TABLE.each { |dex, r| BY_NORMID[norm(r['id'])] = dex.to_i; BY_NAME[norm(r['name'])] = dex.to_i }

def species_dex(tok)
  return tok.to_i if tok.is_a?(Integer) || tok.to_s =~ /\A\d+\z/
  BY_NORMID[norm(tok)] || BY_NAME[norm(tok)]
end

# ---- OT owner + template mon ----
def all_mons(save)
  m = []
  (ivg(save[:player], :@party) || []).each { |pk| m << pk if pk }
  (ivg(save[:storage_system], :@boxes) || []).each { |b| next unless b; (ivg(b, :@pokemon) || []).each { |pk| m << pk if pk } }
  m
end
MONS = all_mons(save)
raise "save has no Pokemon to use as a template" if MONS.empty?
PLAYER_NAME = ivg(save[:player], :@name)
OWNER = (MONS.map { |pk| ivg(pk, :@owner) }.compact.find { |o| ivg(o, :@name) == PLAYER_NAME } || ivg(MONS[0], :@owner))
TEMPLATE = MONS[0]
TEMPLATE_MOVE = (ivg(TEMPLATE, :@moves) || []).first or raise "template has no move object to clone"

STAT_SYMS = PokeMath::STATS

def build_mon(entry, errors, idx)
  pk = clone(TEMPLATE)
  level = (entry['level'] || 50).to_i.clamp(1, 100)

  # species
  if entry['head'] || entry['body']
    hd = species_dex(entry['head']); bd = species_dex(entry['body'])
    (errors << "#[#{idx}] unknown head '#{entry['head']}'"; return nil) unless hd && TABLE[hd.to_s]
    (errors << "#[#{idx}] unknown body '#{entry['body']}'"; return nil) unless bd && TABLE[bd.to_s]
    species_sym = "B#{bd}H#{hd}".to_sym
    base_stats  = PokeMath.fused_base_stats(TABLE[hd.to_s]['base_stats'], TABLE[bd.to_s]['base_stats'])
    growth      = PokeMath.fusion_growth_rate(TABLE[hd.to_s]['growth_rate'], TABLE[bd.to_s]['growth_rate'])
    happ        = TABLE[hd.to_s]['happiness'] || 70
    gender      = 2                       # fusions are genderless
    default_ability = TABLE[bd.to_s]['abilities']&.first
    label       = "#{TABLE[hd.to_s]['name']}/#{TABLE[bd.to_s]['name']}"
  else
    dx = species_dex(entry['species'])
    (errors << "#[#{idx}] unknown species '#{entry['species']}'"; return nil) unless dx && TABLE[dx.to_s]
    rec = TABLE[dx.to_s]
    species_sym = rec['id'].to_sym
    base_stats  = rec['base_stats']; growth = rec['growth_rate']; happ = rec['happiness'] || 70
    gm = { 'male' => 0, 'female' => 1, 'genderless' => 2 }
    gender = gm[entry['gender'].to_s.downcase] || 0
    default_ability = rec['abilities']&.first
    label = rec['name']
  end

  ivs(pk, :@species, species_sym); ivs(pk, :@species_data, nil)
  ivs(pk, :@form, 0); ivs(pk, :@forced_form, nil)
  ivs(pk, :@exp, PokeMath.min_exp(growth, level)); ivs(pk, :@level, level)

  # IVs / EVs
  ivh = {}; evh = {}
  STAT_SYMS.each do |s|
    iv_in = (entry.dig('ivs', s.to_s) || entry.dig('ivs', s.to_s.upcase))
    ev_in = (entry.dig('evs', s.to_s) || entry.dig('evs', s.to_s.upcase))
    ivh[s] = (iv_in.nil? ? 31 : iv_in.to_i).clamp(0, 31)
    evh[s] = (ev_in.nil? ? 0  : ev_in.to_i).clamp(0, 252)
  end
  ivs(pk, :@iv, ivh); ivs(pk, :@ev, evh)
  ivs(pk, :@ivMaxed, STAT_SYMS.map { |s| [s, nil] }.to_h)

  # nature
  nat = norm(entry['nature'])
  nat = 'HARDY' unless PokeMath::NATURES.key?(nat)
  ivs(pk, :@nature, nat.to_sym); ivs(pk, :@nature_for_stats, nil)

  # ability (forced) — validate against ability_set if we have it
  ab = entry['ability'] ? norm(entry['ability']) : (default_ability ? norm(default_ability) : nil)
  if ab && ABILITY_SET && !ABILITY_SET.include?(ab)
    errors << "#[#{idx}] unknown ability '#{entry['ability']}'"; return nil
  end
  ivs(pk, :@ability, ab ? ab.to_sym : nil)
  ivs(pk, :@ability_index, 0); ivs(pk, :@ability2, nil); ivs(pk, :@ability2_index, nil)

  # item
  if entry['item'] && !entry['item'].to_s.empty?
    it = norm(entry['item'])
    if ITEM_SET && !ITEM_SET.include?(it)
      errors << "#[#{idx}] unknown item '#{entry['item']}'"; return nil
    end
    ivs(pk, :@item, it.to_sym)
  else
    ivs(pk, :@item, nil)
  end

  # moves
  move_syms = (entry['moves'] || []).first(4).map { |m| norm(m) }
  bad = move_syms.reject { |m| MOVES.key?(m) }
  (errors << "#[#{idx}] unknown move(s): #{bad.join(', ')}"; return nil) unless bad.empty?
  new_moves = move_syms.map do |m|
    mv = clone(TEMPLATE_MOVE)
    ivs(mv, :@id, m.to_sym); ivs(mv, :@ppup, 0); ivs(mv, :@pp, MOVES[m]['pp'])
    mv
  end
  ivs(pk, :@moves, new_moves)
  ivs(pk, :@first_moves, move_syms.map(&:to_sym))
  ivs(pk, :@learned_moves, [])

  # cosmetics / misc
  ivs(pk, :@name, (entry['nickname'].to_s.empty? ? nil : entry['nickname']))
  ivs(pk, :@shiny, entry['shiny'] ? true : nil)
  ivs(pk, :@gender, gender)
  ivs(pk, :@personalID, rand(2**32))
  ivs(pk, :@owner, clone(OWNER))
  ivs(pk, :@happiness, happ)
  ivs(pk, :@poke_ball, (entry['ball'] ? norm(entry['ball']).to_sym : :POKEBALL))
  ivs(pk, :@obtain_method, 0); ivs(pk, :@obtain_level, level); ivs(pk, :@obtain_map, 0)
  ivs(pk, :@obtain_text, nil); ivs(pk, :@hatched_map, 0)
  ivs(pk, :@timeReceived, Time.now.to_i); ivs(pk, :@timeEggHatched, nil); ivs(pk, :@time_form_set, nil)
  ivs(pk, :@status, :NONE); ivs(pk, :@statusCount, 0); ivs(pk, :@steps_to_hatch, 0)
  ivs(pk, :@pokerus, 0); ivs(pk, :@markings, 0); ivs(pk, :@ribbons, [])
  ivs(pk, :@mail, nil); ivs(pk, :@glitter, nil); ivs(pk, :@hiddenPowerType, nil)
  [:@cool, :@beauty, :@cute, :@smart, :@tough, :@sheen].each { |c| ivs(pk, c, 0) }
  ivs(pk, :@hyper_mode, false) if pk.instance_variable_defined?(:@hyper_mode)
  # clear fusion-exp residue from the template
  [:@exp_gained_since_fused, :@exp_when_fused_head, :@exp_when_fused_body].each { |c| ivs(pk, c, nil) if pk.instance_variable_defined?(c) }
  ivs(pk, :@exp_gained_since_fused, 0) if pk.instance_variable_defined?(:@exp_gained_since_fused)
  ivs(pk, :@fused, nil)
  [:@spriteform_head, :@spriteform_body].each { |c| ivs(pk, c, nil) if pk.instance_variable_defined?(c) }
  ivs(pk, :@sprite_scale, 1) if pk.instance_variable_defined?(:@sprite_scale)

  # stats
  st = PokeMath.all_stats(base_stats, level, ivh, evh, nat)
  st['HP'] = 1 if ivg(pk, :@ability) == :WONDERGUARD
  ivs(pk, :@totalhp, st['HP']); ivs(pk, :@hp, st['HP'])
  ivs(pk, :@attack, st['ATTACK']); ivs(pk, :@defense, st['DEFENSE'])
  ivs(pk, :@spatk, st['SPECIAL_ATTACK']); ivs(pk, :@spdef, st['SPECIAL_DEFENSE']); ivs(pk, :@speed, st['SPEED'])

  # self-validation
  if PokeMath.level_from_exp(growth, ivg(pk, :@exp)) != level
    errors << "#[#{idx}] #{label}: exp/level inconsistent"; return nil
  end
  if st.values.any? { |v| v.nil? || v < 1 }
    errors << "#[#{idx}] #{label}: bad stat #{st.inspect}"; return nil
  end
  { pk: pk, label: label, level: level, box: entry['box'], slot: entry['slot'], mode: (entry['mode'] || 'add') }
end

# Edit an EXISTING mon in place (keeps species/PID/EVs/nature/level/stats).
# Only touches item / ability / moves / nickname — so no stat recompute is needed.
# Used for mons we can't rebuild (triple fusions) or just want to finish.
def apply_edit(boxes, e, errors, idx)
  bi = e['box'].to_i; si = e['slot'].to_i
  box = boxes[bi]
  slots = box ? box.instance_variable_get(:@pokemon) : nil
  pk = slots ? slots[si] : nil
  if pk.nil?
    errors << "#[#{idx}] edit target box #{bi + 1} slot #{si + 1} is empty"; return nil
  end
  if e.key?('item')
    if e['item'].to_s.empty?
      pk.instance_variable_set(:@item, nil)
    else
      it = norm(e['item'])
      (errors << "#[#{idx}] unknown item '#{e['item']}'"; return nil) if ITEM_SET && !ITEM_SET.include?(it)
      pk.instance_variable_set(:@item, it.to_sym)
    end
  end
  if e['ability']
    ab = norm(e['ability'])
    (errors << "#[#{idx}] unknown ability '#{e['ability']}'"; return nil) if ABILITY_SET && !ABILITY_SET.include?(ab)
    pk.instance_variable_set(:@ability, ab.to_sym)
  end
  pk.instance_variable_set(:@name, (e['nickname'].to_s.empty? ? nil : e['nickname'])) if e.key?('nickname')
  if e['moves'].is_a?(Array)
    syms = e['moves'].first(4).map { |m| norm(m) }
    bad = syms.reject { |m| MOVES.key?(m) }
    (errors << "#[#{idx}] unknown move(s): #{bad.join(', ')}"; return nil) unless bad.empty?
    newmoves = syms.map do |m|
      mv = clone(TEMPLATE_MOVE)
      mv.instance_variable_set(:@id, m.to_sym); mv.instance_variable_set(:@ppup, 0); mv.instance_variable_set(:@pp, MOVES[m]['pp'])
      mv
    end
    pk.instance_variable_set(:@moves, newmoves)
    pk.instance_variable_set(:@first_moves, syms.map(&:to_sym))
  end
  { label: (pk.instance_variable_get(:@name) || 'mon'), box: bi + 1, slot: si + 1, mode: 'edit', box_name: (box.instance_variable_get(:@name)) }
end

# ---- state (current working box) ----
STATE_PATH = File.join(DIR, 'editor_state.json')
state = (JSON.parse(File.read(STATE_PATH)) rescue { 'current_box' => 0 })
state['current_box'] = spec['default_box'].to_i if spec['default_box']

# ---- build / edit ----
boxes = ivg(save[:storage_system], :@boxes)
errors = []
built = []
placed = []
(spec['pokemon'] || []).each_with_index do |e, i|
  if (e['mode'] || 'add') == 'edit'
    r = apply_edit(boxes, e, errors, i + 1)
    placed << r if r
  else
    m = build_mon(e, errors, i + 1)
    built << m if m
  end
end

if !errors.empty?
  puts JSON.generate({ 'ok' => false, 'errors' => errors })
  exit 1
end

# ---- place built mons ----
built.each do |b|
  bi = (b[:box] || state['current_box']).to_i.clamp(0, boxes.length - 1)
  box = boxes[bi]
  slots = ivg(box, :@pokemon)
  if b[:mode] == 'replace'
    si = b[:slot].to_i
    if si < 0 || si >= slots.length
      errors << "box #{bi + 1} slot #{si + 1} out of range for #{b[:label]}"; next
    end
    slots[si] = b[:pk]
    placed << { 'label' => b[:label], 'level' => b[:level], 'box' => bi + 1, 'slot' => si + 1, 'mode' => 'replace', 'box_name' => ivg(box, :@name) }
  else
    free = (0...slots.length).find { |i| slots[i].nil? }
    if free.nil?
      errors << "box #{bi + 1} full, could not place #{b[:label]}"; next
    end
    slots[free] = b[:pk]
    placed << { 'label' => b[:label], 'level' => b[:level], 'box' => bi + 1, 'slot' => free + 1, 'mode' => 'add', 'box_name' => ivg(box, :@name) }
  end
end

if !errors.empty?
  puts JSON.generate({ 'ok' => false, 'errors' => errors, 'placed' => placed })
  exit 1
end

Marshal.dump(save, File.open(OUT, 'wb')).close rescue File.binwrite(OUT, Marshal.dump(save))
File.write(STATE_PATH, JSON.generate(state))
puts JSON.generate({ 'ok' => true, 'placed' => placed, 'current_box' => state['current_box'] + 1, 'out' => OUT })
