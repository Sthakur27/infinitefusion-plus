# Build the FINAL combined supply-fix spec (moveset edits + constructed additions),
# with an identity pre-flight so nothing is edited blind.
#
#   ruby tools/sidmod_editor/sim/nsupply_prep.rb [rating_tag] [add_box_idx0]
#
# Safety properties:
#   * reads the LIVE save (edits must target live box/slot)
#   * SKIPS any slot whose occupant differs from the rating snapshot — those mons were
#     reorganised, so their rating (and therefore the "don't touch the core" guard) is
#     misattributed and the edit cannot be justified
#   * records expected nickname+species per edit into a manifest, re-checked immediately
#     before the write
#   * additions go to one empty box; in-game Box 16 (idx 15) is never touched (standing rule)
require_relative 'nstore'
require_relative 'nbattle'

RTAG    = ARGV[0] || 'ou3'
ADD_BOX = (ARGV[1] || 21).to_i          # 0-indexed; 21 = in-game Box 22
raise 'refusing to write to in-game Box 16 (standing rule)' if ADD_BOX == 15
NativeSim.boot!                          # LIVE save
puts "live save: #{NativeSim.save_path_in_use}"

snap = NStore.read_json(RTAG, 'pool.json')
rat  = File.readlines(File.join(NStore.dir(RTAG), 'ratings.csv'))[1..].map { |l| l.chomp.split(',') }
RANK = rat.each_with_index.each_with_object({}) { |(f, i), h| h[f[0]] = i }
COEF = rat.each_with_object({}) { |f, h| h[f[0]] = f[13].to_f }

REMOVAL = %i[RAPIDSPIN DEFOG]
HAZARD  = %i[STEALTHROCK SPIKES TOXICSPIKES]
RECOVER = %i[RECOVER ROOST SOFTBOILED SLACKOFF SYNTHESIS MOONLIGHT MORNINGSUN REST SHOREUP
             STRENGTHSAP WISH AQUARING INGRAIN]
STATUS  = %i[TOXIC WILLOWISP THUNDERWAVE YAWN GLARE POISONPOWDER STUNSPORE CONFUSERAY]
FILLER  = %i[PROTECT DETECT SUBSTITUTE SLEEPTALK AROMATHERAPY HEALBELL SAFEGUARD
             LIGHTSCREEN REFLECT MIST HELPINGHAND CAPTIVATE ATTRACT SPLASH FINALGAMBIT
             COUNTER MIRRORCOAT]

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
def mn(id); (GameData::Move.get(id).name rescue id.to_s); end

def drop_score(m, cur, d)
  md = (GameData::Move.get(m) rescue nil)
  return -999 if !md
  bp = md.base_damage.to_i
  atk = [d[:stats][1].to_i, d[:stats][3].to_i].max
  s = 0
  s += 60 if FILLER.include?(m)
  s -= 200 if m == :SLEEPTALK && cur.include?(:REST)
  s -= 200 if m == :REST && cur.include?(:SLEEPTALK)
  s -= 150 if m == :PROTECT && cur.include?(:WISH)
  s += 70 if RECOVER.include?(m) && (cur & RECOVER).length >= 2
  s += 45 if STATUS.include?(m) && (cur & STATUS).length >= 2
  s += 40 if bp.positive? && atk < 220
  s += 20 if bp.positive? && bp <= 60
  s -= 100 if RECOVER.include?(m) && (cur & RECOVER).length == 1
  s -= 80 if (HAZARD + REMOVAL + [:STICKYWEB]).include?(m)
  s -= 70 if %i[SWORDSDANCE DRAGONDANCE NASTYPLOT CALMMIND QUIVERDANCE BULKUP SHELLSMASH
                COIL AGILITY].include?(m)
  s -= 60 if %i[WHIRLWIND ROAR DRAGONTAIL CIRCLETHROW HAZE].include?(m)
  s -= 50 if %i[UTURN VOLTSWITCH].include?(m)
  s -= 40 if bp >= 90 && atk >= 260
  s -= 30 if d[:types].split('/').include?(md.type.to_s) && bp.positive?
  # never leave a mon unable to deal damage at all: dropping Blissey's Seismic Toss
  # for Defog produced a set of four status moves that cannot break anything
  if bp.positive?
    others = (cur - [m]).count { |o| (GameData::Move.get(o).base_damage.to_i.positive? rescue false) }
    s -= 250 if others.zero?
  end
  s
end

edits = []
skipped_drift = 0
NativeSim.pool(tier: :ou).each do |e|
  d = NativeSim.describe(e[:key])
  ident = "#{d[:name]}|#{d[:species]}"
  s = snap[e[:key]]
  if !s || "#{s['name']}|#{s['species']}" != ident
    skipped_drift += 1
    next                                   # reorganised slot: rating is misattributed
  end
  st = d[:stats]
  bulk = st[0].to_i + st[2].to_i + st[4].to_i
  off  = [st[1].to_i, st[3].to_i].max
  next if bulk < 850 || off > 260
  next if (RANK[e[:key]] || 999) < 30
  cur = e[:moves].map { |m| m.to_s.to_sym }
  mp  = movepool(e[:bases])
  want =
    if (cur & REMOVAL).empty? && ((mp & REMOVAL) - cur).any?
      ((mp & [:RAPIDSPIN]) - cur).first || ((mp & [:DEFOG]) - cur).first
    elsif (cur & HAZARD).empty? && ((mp & HAZARD) - cur).any?
      ((mp & [:STEALTHROCK]) - cur).first || ((mp & HAZARD) - cur).first
    end
  next if !want
  cand = cur.each_with_index.map { |m, i| [i, m, drop_score(m, cur, d)] }.max_by { |x| x[2] }
  next if !cand || cand[2] < 40
  nm = cur.dup; nm[cand[0]] = want
  edits << { key: e[:key], ident: ident, name: d[:name], species: d[:species],
             box0: d[:box] - 1, slot0: d[:slot] - 1, coef: COEF[e[:key]].to_f,
             add: want, drop: cand[1], old: cur, new: nm,
             kind: REMOVAL.include?(want) ? 'removal' : 'hazard' }
end

rem = edits.select { |x| x[:kind] == 'removal' }.sort_by { |x| -x[:coef] }.first(10)
haz = edits.select { |x| x[:kind] == 'hazard'  }.sort_by { |x| -x[:coef] }.first(8)
chosen = rem + haz

adds = NStore::PARSE.call(File.binread(File.join(NStore.dir(RTAG), 'utility_adds_spec.json')))['pokemon']
adds.each { |a| a['box'] = ADD_BOX }

puts "\nEDITS (#{chosen.length}) — skipped #{skipped_drift} slots whose occupant changed since the snapshot"
chosen.each { |x|
  puts "  Box%-2d slot%-2d %-13s %-22s  drop %-14s add %-14s" %
       [x[:box0] + 1, x[:slot0] + 1, x[:name], x[:species][0, 22], mn(x[:drop]), mn(x[:add])] }
puts "\nADDITIONS (#{adds.length}) -> in-game Box #{ADD_BOX + 1} (idx #{ADD_BOX})"
adds.each { |a| puts "  %-11s %-12s/%-12s %-13s %s" %
  [a['nickname'], a['head'], a['body'], a['ability'], a['moves'].join('/')] }

spec = { 'pokemon' =>
  chosen.map { |x| { 'mode' => 'edit', 'box' => x[:box0], 'slot' => x[:slot0],
                     'moves' => x[:new].map(&:to_s) } } + adds }
sf = File.join(NStore.dir(RTAG), 'supply_combined_spec.json')
File.binwrite(sf, NStore::GEN.call(spec))
mf = File.join(NStore.dir(RTAG), 'supply_manifest.json')
File.binwrite(mf, NStore::GEN.call('add_box' => ADD_BOX,
  'edits' => chosen.map { |x| { 'box' => x[:box0], 'slot' => x[:slot0], 'expect' => x[:ident],
                                'add' => x[:add].to_s, 'drop' => x[:drop].to_s } }))
puts "\nspec     -> #{sf}   (#{spec['pokemon'].length} operations)"
puts "manifest -> #{mf}   (identity pre-flight)"
puts "\nnet OU pool effect: removal 6 -> #{6 + rem.length + adds.count { |a| (a['moves'] & %w[RAPIDSPIN DEFOG]).any? }}," \
     " hazards 31 -> #{31 + haz.length + adds.count { |a| (a['moves'] & %w[STEALTHROCK SPIKES TOXICSPIKES]).any? }}"
