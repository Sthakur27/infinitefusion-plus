# Build a CONSERVATIVE supply-fix proposal + the edit spec.
#   ruby tools/sidmod_editor/sim/nsupplyplan.rb [rating_tag] [out_spec.json]
#
# Rules, chosen so this cannot quietly weaken Sid's real teams:
#   * only DEFENSIVE mons (bulk >= 850, and offence <= 260 in both attack stats) —
#     an offensive mon's 4th slot is its coverage and is not spare capacity
#   * never touch the top 30 rated mons (they are load-bearing on existing teams)
#   * the dropped move must be genuinely redundant, scored: a second recovery move,
#     Protect, a duplicate status, or a weak non-STAB attack on a mon that cannot
#     attack anyway. If nothing is redundant, the mon is skipped.
#   * Defog is preferred over Rapid Spin only where Rapid Spin is unavailable, so the
#     pool gets both kinds of hazard control.
require_relative 'nstore'
require_relative 'nbattle'

RTAG = ARGV[0] || 'ou3'
OUT  = ARGV[1] || File.join(NStore.dir(RTAG), 'supplyfix_spec.json')
NativeSim.boot!

rat = File.readlines(File.join(NStore.dir(RTAG), 'ratings.csv'))[1..].map { |l| l.chomp.split(',') }
RANK = rat.each_with_index.each_with_object({}) { |(f, i), h| h[f[0]] = i }   # 0 = best
COEF = rat.each_with_object({}) { |f, h| h[f[0]] = f[13].to_f }

REMOVAL = %i[RAPIDSPIN DEFOG]
HAZARD  = %i[STEALTHROCK SPIKES TOXICSPIKES]
RECOVER = %i[RECOVER ROOST SOFTBOILED SLACKOFF SYNTHESIS MOONLIGHT MORNINGSUN REST SHOREUP
             STRENGTHSAP WISH AQUARING INGRAIN]
STATUS  = %i[TOXIC WILLOWISP THUNDERWAVE YAWN GLARE POISONPOWDER STUNSPORE CONFUSERAY
             SWAGGER FLATTER SCREECH]
FILLER  = %i[PROTECT DETECT SUBSTITUTE REST SLEEPTALK AROMATHERAPY HEALBELL SAFEGUARD
             LIGHTSCREEN REFLECT MIST HELPINGHAND CAPTIVATE ATTRACT SPLASH]

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

# Redundancy score for dropping move `m` from a mon: HIGHER = safer to drop.
def drop_score(m, cur, d)
  md = (GameData::Move.get(m) rescue nil)
  return -999 if !md
  bp = md.base_damage.to_i
  atk_stat = [d[:stats][1].to_i, d[:stats][3].to_i].max
  s = 0
  s += 60 if FILLER.include?(m)
  # functional pairs: dropping half of one breaks the other
  s -= 200 if m == :SLEEPTALK && cur.include?(:REST)        # RestTalk
  s -= 200 if m == :REST && cur.include?(:SLEEPTALK)
  s -= 150 if m == :PROTECT && (cur & %i[WISH LEECHSEED TOXIC]).length >= 2   # stall loop
  s -= 150 if m == :PROTECT && cur.include?(:WISH)          # Wish + Protect passing
  s += 70 if RECOVER.include?(m) && (cur & RECOVER).length >= 2      # a second heal is waste
  s += 45 if STATUS.include?(m) && (cur & STATUS).length >= 2        # duplicate status
  s += 40 if bp.positive? && atk_stat < 220                          # it cannot hit anyway
  s += 20 if bp.positive? && bp <= 60
  s -= 100 if RECOVER.include?(m) && (cur & RECOVER).length == 1     # its only heal
  s -= 80 if %i[STEALTHROCK SPIKES TOXICSPIKES STICKYWEB RAPIDSPIN DEFOG].include?(m)
  s -= 70 if %i[SWORDSDANCE DRAGONDANCE NASTYPLOT CALMMIND QUIVERDANCE BULKUP SHELLSMASH
                COIL AGILITY].include?(m)
  s -= 60 if %i[WHIRLWIND ROAR DRAGONTAIL CIRCLETHROW HAZE].include?(m)
  s -= 50 if %i[UTURN VOLTSWITCH].include?(m)
  s -= 40 if bp >= 90 && atk_stat >= 260                             # a real attack
  s -= 30 if d[:types].split('/').include?(md.type.to_s) && bp.positive?   # STAB
  s
end

plan = []
NativeSim.pool(tier: :ou).each do |e|
  d = NativeSim.describe(e[:key])
  st = d[:stats]
  bulk = st[0].to_i + st[2].to_i + st[4].to_i
  off  = [st[1].to_i, st[3].to_i].max
  next if bulk < 850 || off > 260                      # defensive mons only
  next if (RANK[e[:key]] || 999) < 30                  # never touch the rated core
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
  next if !cand || cand[2] < 40                        # nothing safely spare
  new_moves = cur.dup; new_moves[cand[0]] = want
  plan << { key: e[:key], name: d[:name], species: d[:species], types: d[:types],
            box: d[:box], slot: d[:slot], bulk: bulk, coef: COEF[e[:key]].to_f,
            rank: RANK[e[:key]], add: want, drop: cand[1], drop_slot: cand[0],
            drop_score: cand[2], old: cur, new: new_moves }
end

rem = plan.select { |p| REMOVAL.include?(p[:add]) }.sort_by { |p| -(p[:coef] + p[:bulk] / 2000.0) }
haz = plan.select { |p| HAZARD.include?(p[:add]) }.sort_by  { |p| -(p[:coef] + p[:bulk] / 2000.0) }
CHOSEN = rem.first(10) + haz.first(8)

puts "PROPOSED EDITS (#{CHOSEN.length}) — defensive mons only, rated core untouched"
puts "=" * 104
CHOSEN.each do |p|
  puts "  %-13s %-22s %-13s bulk %-5d coef %+.3f rank %-4s Box%-3d slot%-3d" %
       [p[:name], p[:species][0, 22], p[:types], p[:bulk], p[:coef], p[:rank], p[:box], p[:slot]]
  puts "      %s" % p[:old].map { |m| mn(m) }.join(' / ')
  puts "      -> ADD %-14s replacing %-16s (redundancy score %d)" %
       [mn(p[:add]), mn(p[:drop]), p[:drop_score]]
end
puts "\nnet effect on the OU pool:"
puts "  removal users: 6 -> #{6 + rem.first(10).length}"
puts "  hazard users:  31 -> #{31 + haz.first(8).length}"

spec = { 'pokemon' => CHOSEN.map { |p|
  { 'mode' => 'edit', 'box' => p[:box] - 1, 'slot' => p[:slot] - 1,
    'moves' => p[:new].map(&:to_s) } } }
File.binwrite(OUT, NStore::GEN.call(spec))
puts "\nspec -> #{OUT}  (#{spec['pokemon'].length} edits, 0-indexed box/slot, moves-only so no stat recompute)"
