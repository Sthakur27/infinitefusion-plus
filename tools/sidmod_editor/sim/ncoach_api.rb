# API-DRIVEN MASS COACH. Builds engine ground truth for every mon in the target boxes,
# asks Claude (via sim/.apikey, not via chat) for an optimal Lv100 set, validates the
# reply hard, retries with the error fed back, then emits an edit spec.
#
#   ruby tools/sidmod_editor/sim/ncoach_api.rb <box_idx0,...> [model] [threads] [out_tag]
#     e.g. ruby ...\ncoach_api.rb 28,29,30
#
# Every set is validated before it can reach the save:
#   * 4 unique moves, all inside head u body (level-up u tutor u egg)
#   * ability from the fusion's own ability list
#   * item id that EXISTS in this build (HEAVYDUTYBOOTS does not, hence the check)
#   * EVs <= 252 each and <= 508 total; IVs forced to 31; level forced to 100
# A mon whose set never validates is SKIPPED, never written with a guess.
require 'json'
require 'thread'
require_relative 'claude_client'      # captures stdlib JSON before the engine patches it
require_relative 'nstore'
require_relative 'nbattle'

BOXES   = (ARGV[0] || '28,29,30').split(',').map(&:to_i)
MODEL   = ARGV[1] || 'claude-sonnet-5'
THREADS = (ARGV[2] || 6).to_i
TAG     = ARGV[3] || 'coach1'
MAX_TRY = 3

NativeSim.boot!                        # LIVE save
DIR = NStore.init(TAG)
puts "coaching boxes #{BOXES.map { |b| b + 1 }.join(', ')} (idx #{BOXES.join(',')}) with #{MODEL}"

STATS  = %i[HP ATTACK DEFENSE SPECIAL_ATTACK SPECIAL_DEFENSE SPEED]
SHORT  = { HP: 'HP', ATTACK: 'Atk', DEFENSE: 'Def', SPECIAL_ATTACK: 'SpA',
           SPECIAL_DEFENSE: 'SpD', SPEED: 'Spe' }

# ---- items that exist in THIS build, curated to competitively sensible ones -----
WANT_ITEMS = %w[LEFTOVERS LIFEORB CHOICESCARF CHOICEBAND CHOICESPECS ASSAULTVEST EVIOLITE
                ROCKYHELMET BLACKSLUDGE TOXICORB FLAMEORB FOCUSSASH SITRUSBERRY LUMBERRY
                WEAKNESSPOLICY EXPERTBELT MUSCLEBAND WISEGLASSES SCOPELENS KINGSROCK
                THICKCLUB LIGHTBALL SOULDEW METALCOAT BLACKBELT CHARCOAL MYSTICWATER
                MIRACLESEED MAGNET TWISTEDSPOON NEVERMELTICE SHARPBEAK POISONBARB
                SOFTSAND HARDSTONE SILVERPOWDER SPELLTAG DRAGONFANG BLACKGLASSES
                METRONOME QUICKCLAW WIDELENS ZOOMLENS AIRBALLOON SHELLBELL BRIGHTPOWDER
                NORMALGEM SILKSCARF POWERHERB REDCARD EJECTBUTTON SAFETYGOGGLES
                HEATROCK DAMPROCK SMOOTHROCK ICYROCK LIGHTCLAY BINDINGBAND GRIPCLAW
                FLYINGGEM LEEK STICK LUCKYPUNCH DEEPSEATOOTH DEEPSEASCALE]
ITEMS = WANT_ITEMS.select { |i| (GameData::Item.exists?(i.to_sym) rescue false) }
ITEM_OK = ITEMS.to_h { |i| [i, true] }
NATURES = (GameData::Nature.keys.map(&:to_s) rescue
           %w[ADAMANT JOLLY MODEST TIMID BOLD IMPISH CAREFUL CALM RELAXED SASSY BRAVE QUIET
              NAIVE HASTY LONELY MILD RASH NAUGHTY GENTLE LAX HARDY SERIOUS DOCILE BASHFUL QUIRKY])
GOOD_NATURES = %w[ADAMANT JOLLY MODEST TIMID BOLD IMPISH CAREFUL CALM RELAXED SASSY BRAVE
                  QUIET NAIVE HASTY LONELY MILD RASH GENTLE LAX]

def bases_of(pk)
  if (pk.isTripleFusion? rescue false)
    c = (get_triple_fusion_components(pk.species) rescue nil)
    return c ? c.map { |d| (GameData::Species.get(d).id rescue d) } : [pk.species]
  elsif (pk.isFusion? rescue false)
    [(GameData::Species.get(pk.head_id).id rescue pk.head_id),
     (GameData::Species.get(pk.body_id).id rescue pk.body_id)]
  else
    [pk.species]
  end
end

def movepool(bases)
  s = []
  bases.each do |b|
    sp = (GameData::Species.get(b.to_s.to_sym) rescue nil) or next
    (sp.moves rescue []).each { |m| s << (m.is_a?(Array) ? m[1] : m) }
    (sp.tutor_moves rescue []).each { |m| s << m }
    (sp.egg_moves rescue []).each { |m| s << m }
  end
  s.compact.map { |m| m.to_s.to_sym }.uniq
end

def move_line(id)
  m = (GameData::Move.get(id) rescue nil) or return nil
  cat = %w[Physical Special Status][m.category] || '?'
  bp  = m.base_damage.to_i
  acc = m.accuracy.to_i
  "#{id} (#{m.type} #{cat}#{bp.positive? ? " #{bp}bp" : ''}#{acc.positive? && acc < 100 ? " #{acc}%" : ''})"
end

def eff_profile(types)
  ts = types.map { |t| t.to_s.to_sym }
  weak = []; res = []; imm = []
  GameData::Type.keys.each do |at|
    next if (GameData::Type.get(at).pseudo_type rescue false)
    m = (Effectiveness.calculate(at, *ts).to_f / Effectiveness::NORMAL_EFFECTIVE rescue 1.0)
    if m > 1.0 then weak << "#{at} x#{m.round(2)}"
    elsif m.zero? then imm << at.to_s
    elsif m < 1.0 then res << "#{at} x#{m.round(2)}"
    end
  end
  [weak, res, imm]
end

# ---- gather targets --------------------------------------------------------------
targets = []
BOXES.each do |b|
  (0...$PokemonStorage.maxPokemon(b)).each do |i|
    pk = $PokemonStorage[b, i]
    next if pk.nil? || (pk.egg? rescue false)
    bases = bases_of(pk)
    mp = movepool(bases)
    next if mp.empty?
    abil = begin
      (0..2).map { |n| pk.getAbilityList rescue nil }.compact.first
    rescue
      nil
    end
    abilities = begin
      lst = (pk.getAbilityList rescue []) || []
      lst.map { |a| (a.is_a?(Array) ? a[0] : a).to_s }.uniq
    rescue
      [(pk.ability&.id.to_s rescue nil)].compact
    end
    abilities = [(pk.ability&.id.to_s rescue 'UNKNOWN')] if abilities.empty?
    types = (pk.types rescue []).map { |t| t.respond_to?(:id) ? t.id : t }
    targets << { box: b, slot: i, nick: (pk.name || pk.speciesName).to_s,
                 species: (pk.speciesName rescue '?'), bases: bases.map(&:to_s),
                 level: pk.level, types: types.map(&:to_s), abilities: abilities,
                 cur_ability: (pk.ability&.id.to_s rescue nil),
                 cur_item: (pk.item&.id.to_s rescue 'NONE'),
                 cur_nature: (pk.nature&.id.to_s rescue nil),
                 cur_moves: (pk.moves.map { |m| m.id.to_s } rescue []),
                 base_stats: STATS.to_h { |s| [SHORT[s], (pk.baseStats[s] rescue nil)] },
                 l100_stats: STATS.to_h { |s| [SHORT[s], (pk.calcStats && nil) || nil] },
                 movepool: mp.map { |m| move_line(m) }.compact }
  end
end
puts "targets: #{targets.length} mons"

SYS = <<~TXT
  You are a competitive Pokemon team-builder working in Pokemon Infinite Fusion (a fusion
  romhack, roughly gen 7/8 mechanics). You will be given ONE fused Pokemon with its real
  engine data: typing, base stats, the abilities it can legally have, its complete legal
  movepool, and its defensive type profile.

  Produce the strongest possible LEVEL 100 competitive set for it. It will be used in
  6v6 singles against other level-100 fully-invested teams.

  Rules you MUST follow:
  - exactly 4 moves, all chosen from the provided MOVEPOOL list, no duplicates
  - ability chosen from the provided ABILITIES list
  - item chosen from the provided ITEMS list
  - nature chosen from the provided NATURES list
  - EVs: any stat <= 252, total <= 508. Use whole numbers. Invest for a clear role.
  - IVs are always perfect (31) and level is always 100 — do not include them.

  Build to the Pokemon's actual strengths: check the base stats before choosing a
  physical or special set, pick a nature that boosts the stat you actually use and drops
  one you do not, and match the item to the plan (Choice items for immediate power,
  Leftovers/Eviolite for longevity, Life Orb for a breaker, Toxic/Flame Orb only with
  Poison Heal / Guts / Magic Guard style abilities, Thick Club only for Cubone/Marowak).
  Prefer a coherent plan (wall, setup sweeper, breaker, pivot, hazard setter) over four
  unrelated attacks. Include recovery or utility when the stats support a defensive role.

  Reply with ONLY a JSON object, no prose, no markdown fence:
  {"role":"<short label>","nature":"NATURE","ability":"ABILITY","item":"ITEM",
   "moves":["MOVE1","MOVE2","MOVE3","MOVE4"],
   "evs":{"HP":0,"ATTACK":0,"DEFENSE":0,"SPECIAL_ATTACK":0,"SPECIAL_DEFENSE":0,"SPEED":0},
   "why":"<one sentence>"}
TXT

def user_prompt(t)
  weak, res, imm = eff_profile(t[:types])
  <<~U
    POKEMON: #{t[:nick]} = #{t[:species]} (fusion of #{t[:bases].join(' + ')})
    TYPING: #{t[:types].join('/')}
    BASE STATS: #{t[:base_stats].map { |k, v| "#{k} #{v}" }.join('  ')}
    DEFENSIVE PROFILE: weak to #{weak.empty? ? 'nothing' : weak.join(', ')}
      resists #{res.empty? ? 'nothing' : res.join(', ')}#{imm.empty? ? '' : "; immune to #{imm.join(', ')}"}
    ABILITIES (choose one): #{t[:abilities].join(', ')}
    NATURES (choose one): #{GOOD_NATURES.join(' ')}
    ITEMS (choose one): #{ITEMS.join(' ')}
    CURRENT (probably suboptimal) SET: L#{t[:level]} #{t[:cur_nature]} #{t[:cur_ability]} @#{t[:cur_item]} — #{t[:cur_moves].join('/')}

    MOVEPOOL (#{t[:movepool].length} legal moves — choose 4 by their CAPITALISED id):
    #{t[:movepool].join(', ')}
  U
end

def validate(t, s)
  errs = []
  mp = t[:movepool].map { |x| x.split(' ').first }
  mv = (s['moves'] || []).map(&:to_s)
  errs << "need exactly 4 moves, got #{mv.length}" if mv.length != 4
  errs << 'duplicate moves' if mv.uniq.length != mv.length
  bad = mv - mp
  errs << "moves not in movepool: #{bad.join(',')}" if bad.any?
  errs << "ability #{s['ability']} not in #{t[:abilities].join(',')}" unless t[:abilities].include?(s['ability'].to_s)
  errs << "item #{s['item']} does not exist in this build" unless ITEM_OK[s['item'].to_s]
  errs << "nature #{s['nature']} invalid" unless GOOD_NATURES.include?(s['nature'].to_s)
  ev = s['evs'] || {}
  tot = 0
  STATS.each do |k|
    v = ev[k.to_s].to_i
    errs << "#{k} EV #{v} > 252" if v > 252
    errs << "#{k} EV negative" if v < 0
    tot += v
  end
  errs << "EV total #{tot} > 508" if tot > 508
  errs
end

mutex = Mutex.new
results = {}
failures = []
queue = targets.each_with_index.to_a
threads = Array.new([THREADS, queue.length].min) do
  Thread.new do
    loop do
      t, idx = mutex.synchronize { queue.shift }
      break if !t
      set = nil; last = nil
      MAX_TRY.times do |attempt|
        prompt = user_prompt(t)
        prompt += "\n\nYour previous reply was rejected: #{last}\nFix it and reply with JSON only." if last
        begin
          raw = ClaudeClient.complete(system: SYS, user: prompt, model: MODEL,
                                      max_tokens: 700, cache: true)
          txt = raw.to_s.strip.sub(/\A```(?:json)?/, '').sub(/```\z/, '').strip
          cand = ClaudeClient::PARSE.call(txt)
          errs = validate(t, cand)
          if errs.empty?
            set = cand
            break
          end
          last = errs.join('; ')
        rescue => e
          last = "#{e.class}: #{e.message[0, 120]}"
        end
      end
      mutex.synchronize do
        if set
          results[[t[:box], t[:slot]]] = [t, set]
          puts "  [ok]   Box%-3d slot%-3d %-12s %-16s %s @%s" %
               [t[:box] + 1, t[:slot] + 1, t[:nick], set['role'].to_s[0, 16],
                set['nature'], set['item']]
        else
          failures << [t, last]
          puts "  [FAIL] Box%-3d slot%-3d %-12s — %s" % [t[:box] + 1, t[:slot] + 1, t[:nick], last]
        end
      end
    end
  end
end
threads.each(&:join)

puts "\ncoached #{results.length}/#{targets.length}  (failed #{failures.length})"

pokemon = results.values.map do |t, s|
  { 'mode' => 'edit', 'box' => t[:box], 'slot' => t[:slot], 'level' => 100,
    'nature' => s['nature'], 'ability' => s['ability'], 'item' => s['item'],
    'moves' => s['moves'],
    'evs' => STATS.to_h { |k| [k.to_s, (s['evs'][k.to_s] || 0).to_i] },
    'ivs' => STATS.to_h { |k| [k.to_s, 31] } }
end
sf = File.join(DIR, 'coach_spec.json')
File.binwrite(sf, NStore::GEN.call('pokemon' => pokemon))
rep = results.values.map { |t, s|
  { 'box' => t[:box] + 1, 'slot' => t[:slot] + 1, 'nick' => t[:nick], 'species' => t[:species],
    'types' => t[:types].join('/'), 'role' => s['role'], 'nature' => s['nature'],
    'ability' => s['ability'], 'item' => s['item'], 'moves' => s['moves'],
    'evs' => s['evs'],
    'ev_display' => STATS.map { |k| v = (s['evs'][k.to_s] || 0).to_i; v.zero? ? nil : "#{SHORT[k]}#{v}" }
                         .compact.join('/'),
    'ev_total' => STATS.sum { |k| (s['evs'][k.to_s] || 0).to_i },
    'why' => s['why'],
    'was' => "L#{t[:level]} #{t[:cur_nature]} @#{t[:cur_item]} #{t[:cur_moves].join('/')}" } }
File.binwrite(File.join(DIR, 'coach_report.json'), NStore::GEN.call(rep))
puts "spec   -> #{sf}  (#{pokemon.length} edits)"
puts "report -> #{File.join(DIR, 'coach_report.json')}"
failures.each { |t, e| puts "  unresolved: Box#{t[:box] + 1} slot#{t[:slot] + 1} #{t[:nick]} — #{e}" }
