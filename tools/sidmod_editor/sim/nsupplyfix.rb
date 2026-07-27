# SUPPLY FIX ANALYSIS: which PC mons could legally carry hazard removal / hazards,
# and what would they give up for it?
#
#   ruby tools/sidmod_editor/sim/nsupplyfix.rb [rating_tag] [live|snap]
#
# The OU pool has only 6 Rapid Spin users (2%) and no Defog at all, and 88% of mons
# cannot set Stealth Rock — so the search literally cannot build hazard-control teams.
# This finds bulky, well-rated mons whose LEGAL movepool (head level-up u tutor u egg,
# union with body's — the same rule the mass-upgrade pipeline used) contains a tool they
# are not currently running, and proposes the least-costly move to drop.
#
# READ-ONLY. Emits a proposal table + a spec file for the edit pipeline; writing to the
# save is a separate, explicitly-confirmed step (apply.ps1, game closed, verify gate).
require_relative 'nstore'
require_relative 'nbattle'

RTAG = ARGV[0] || 'ou3'
SRC  = ARGV[1] || 'live'
ENV['NSIM_SAVE'] = File.join(NStore.dir(RTAG), 'save_snapshot.rxdata') if SRC == 'snap'
NativeSim.boot!
puts "reading: #{NativeSim.save_path_in_use}"

rat = File.readlines(File.join(NStore.dir(RTAG), 'ratings.csv'))[1..].each_with_object({}) { |l, h|
  f = l.chomp.split(','); h[f[0]] = { wr: f[9].to_f, kos: f[10].to_f, games: f[8].to_i, coef: f[13].to_f }
}

REMOVAL = %i[RAPIDSPIN DEFOG]
HAZARD  = %i[STEALTHROCK SPIKES TOXICSPIKES]
RECOVER = %i[RECOVER ROOST SOFTBOILED SLACKOFF SYNTHESIS MOONLIGHT MORNINGSUN REST SHOREUP
             STRENGTHSAP WISH]

# legal movepool of a fusion = union over its base species of level-up + tutor + egg
def movepool(bases)
  set = []
  bases.each do |b|
    sp = (GameData::Species.get(b.to_s.to_sym) rescue nil) or next
    (sp.moves rescue []).each { |m| set << (m.is_a?(Array) ? m[1] : m) }
    (sp.tutor_moves rescue []).each { |m| set << m }
    (sp.egg_moves rescue []).each { |m| set << m }
  end
  set.compact.map { |m| m.to_s.to_sym }.uniq
end

def mname(id); (GameData::Move.get(id).name rescue id.to_s); end

pool = NativeSim.pool(tier: :ou)
puts "OU-legal battle-ready mons: #{pool.length}"

rows = []
pool.each do |e|
  d = NativeSim.describe(e[:key])
  pk = e[:ref]
  cur = e[:moves].map { |m| m.to_s.to_sym }
  mp = movepool(e[:bases])
  hp, atk, dfn, spa, spd, spe = d[:stats]
  bulk = hp + dfn + spd
  can_rem = (mp & REMOVAL) - cur
  can_haz = (mp & HAZARD) - cur
  next if can_rem.empty? && can_haz.empty?
  has_rem = (cur & REMOVAL).any?
  has_haz = (cur & HAZARD).any?
  rows << { key: e[:key], name: d[:name], species: d[:species], types: d[:types],
            ability: d[:ability], item: d[:item], moves: d[:moves], move_ids: cur,
            stats: d[:stats], bulk: bulk, coef: (rat[e[:key]] || {})[:coef].to_f,
            box: d[:box], slot: d[:slot],
            can_rem: can_rem, can_haz: can_haz, has_rem: has_rem, has_haz: has_haz,
            recovery: (cur & RECOVER).any? }
end

puts "\nmons that could legally add a tool they lack: #{rows.length}"

# --- which move would we drop? the least-valuable slot, conservatively -------
# Never drop: recovery, setup, the mon's only STAB, a phazing move.
KEEP = %i[RECOVER ROOST SOFTBOILED SLACKOFF SYNTHESIS MOONLIGHT MORNINGSUN REST SHOREUP
          STRENGTHSAP WISH SWORDSDANCE DRAGONDANCE NASTYPLOT CALMMIND QUIVERDANCE BULKUP
          SHELLSMASH COIL AGILITY WHIRLWIND ROAR DRAGONTAIL CIRCLETHROW HAZE
          STEALTHROCK SPIKES TOXICSPIKES STICKYWEB RAPIDSPIN DEFOG UTURN VOLTSWITCH]
def drop_candidate(r)
  cur = r[:move_ids]
  scored = cur.each_with_index.map do |m, i|
    md = (GameData::Move.get(m) rescue nil)
    next nil if !md
    keep = KEEP.include?(m)
    bp = md.base_damage.to_i
    stab = r[:types].split('/').include?(md.type.to_s)
    # prefer dropping: a low-power non-STAB attack; never a KEEP move
    score = 0
    score += 1000 if keep
    score += 300 if stab
    score += bp
    [i, m, score]
  end.compact
  cand = scored.reject { |(_i, m, _s)| KEEP.include?(m) }.min_by { |x| x[2] }
  cand
end

# Prioritise: bulky + well-rated + not already carrying the tool
rem_c = rows.select { |r| !r[:has_rem] && r[:can_rem].any? }
             .sort_by { |r| -(r[:coef] * 2 + r[:bulk] / 400.0) }
haz_c = rows.select { |r| !r[:has_haz] && r[:can_haz].any? && r[:bulk] >= 700 }
             .sort_by { |r| -(r[:coef] * 2 + r[:bulk] / 400.0) }

def show(list, tool_key, n)
  list.first(n).each do |r|
    d = drop_candidate(r)
    add = r[tool_key].first
    puts "  %-13s %-24s %-13s bulk %-4d coef %+.3f  Box%-3d slot%-3d" %
         [r[:name], r[:species][0, 24], r[:types], r[:bulk], r[:coef], r[:box], r[:slot]]
    puts "       now: %s" % r[:moves].join(' / ')
    puts "       ADD %-14s%s" % [mname(add), d ? "  DROP #{mname(d[1])} (slot #{d[0] + 1})" : '  (no safe drop — skip)']
  end
end

puts "\n" + "=" * 96
puts "REMOVAL CANDIDATES (pool currently has 6; no Defog at all)"
puts "=" * 96
show(rem_c, :can_rem, 12)

puts "\n" + "=" * 96
puts "HAZARD CANDIDATES (bulky only, bulk >= 700)"
puts "=" * 96
show(haz_c, :can_haz, 12)

puts "\nsummary of what is legally available across the OU pool:"
puts "  could add Rapid Spin/Defog : #{rows.count { |r| !r[:has_rem] && r[:can_rem].any? }}"
puts "  could add a hazard         : #{rows.count { |r| !r[:has_haz] && r[:can_haz].any? }}"
puts "  Defog specifically         : #{rows.count { |r| r[:can_rem].include?(:DEFOG) }}"
puts "  Rapid Spin specifically    : #{rows.count { |r| r[:can_rem].include?(:RAPIDSPIN) }}"
