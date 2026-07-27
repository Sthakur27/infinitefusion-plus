# COMPETITIVE AUDIT of a ladder's best team per niche — the checks a human team-builder
# would run, computed from the real engine instead of eyeballed:
#   * full sets (fusion head/body, ability, item, moves, EVs, stats)
#   * defensive type profile: how many members each attacking type hits super-effectively
#     (a type that hits 3+ of six is a genuine hole)
#   * role audit: hazard setter / hazard removal / recovery / speed control / priority /
#     status / phazing / win condition
#   * plan coherence for the weather and Trick Room niches: does the payoff actually
#     benefit from what the team sets?
#   ruby tools/sidmod_editor/sim/nteamaudit.rb <ladder_tag> [teams_per_niche]
require_relative 'nstore'
require_relative 'nbattle'
require_relative 'nniche'

LTAG = ARGV[0] || 'ladder_ou3'
PER  = (ARGV[1] || 1).to_i
ENV['NSIM_SAVE'] = File.join(NStore.dir(LTAG), 'save_snapshot.rxdata')
NativeSim.boot!
st = NStore::PARSE.call(File.binread(File.join(NStore.dir(LTAG), 'ladder.json')))
meta = NativeSim.all_pool.each_with_object({}) { |e, h|
  d = NativeSim.describe(e[:key])
  h[e[:key]] = { moves: d[:moves], ability: d[:ability], item: d[:item], types: d[:types],
                 stats: d[:stats], roles: d[:roles].split(','), bases: e[:bases].map(&:to_s),
                 name: d[:name], species: d[:species] }
}
POOL = NStore.read_json(LTAG, 'pool.json')
def sp(x); (GameData::Species.get(x.to_s.to_sym).name rescue x.to_s); end

ATK = GameData::Type.keys.reject { |t| (GameData::Type.get(t).pseudo_type rescue false) }

def eff(atk, types)
  ts = types.map { |t| t.to_s.to_sym }
  (Effectiveness.calculate(atk, *ts).to_f / Effectiveness::NORMAL_EFFECTIVE rescue 1.0)
end

HAZ  = ['Stealth Rock', 'Spikes', 'Toxic Spikes', 'Sticky Web']
REM  = ['Rapid Spin', 'Defog', 'Court Change']
REC  = ['Recover', 'Roost', 'Soft-Boiled', 'Slack Off', 'Synthesis', 'Moonlight', 'Morning Sun',
        'Rest', 'Wish', 'Shore Up', 'Strength Sap', 'Leech Seed', 'Aqua Ring', 'Ingrain']
SET  = Niche::SETUP
PRI  = Niche::PRIORITY
PHZ  = Niche::PHAZE
STAT = ['Toxic', 'Will-O-Wisp', 'Thunder Wave', 'Spore', 'Sleep Powder', 'Glare', 'Nuzzle',
        'Yawn', 'Taunt', 'Encore', 'Knock Off', 'Trick']
RAIN_MOVES = ['Surf', 'Hydro Pump', 'Waterfall', 'Scald', 'Aqua Jet', 'Liquidation', 'Water Spout',
              'Thunder', 'Hurricane', 'Aqua Tail', 'Muddy Water', 'Water Pulse', 'Wave Crash']
SUN_MOVES  = ['Fire Blast', 'Flamethrower', 'Flare Blitz', 'Overheat', 'Heat Wave', 'V-create',
              'Solar Beam', 'Fire Punch', 'Sacred Fire', 'Eruption', 'Blaze Kick', 'Weather Ball']

def audit(name, keys, meta, elo)
  puts "\n" + "=" * 100
  puts "#{name}  (Elo #{'%.0f' % elo}, niche #{Niche.classify(keys, meta)})"
  puts "=" * 100
  keys.each_with_index do |k, i|
    m = meta[k]
    b = m[:bases]
    fus = b.length == 2 ? "#{m[:species]} (h:#{sp(b[0])}/b:#{sp(b[1])})" : m[:species]
    puts "  %d. %-13s %-34s %-14s %-13s %-13s" % [i + 1, m[:name], fus, m[:types], m[:ability], m[:item]]
    puts "       %s" % m[:moves].join(' / ')
    puts "       HP%-4d Atk%-4d Def%-4d SpA%-4d SpD%-4d Spe%-4d" % m[:stats]
  end

  # ---- defensive holes
  weak = {}
  ATK.each do |at|
    hits = keys.count { |k| eff(at, meta[k][:types].split('/')) > 1.0 }
    weak[at] = hits if hits >= 3
  end
  puts "\n  DEFENSIVE HOLES (types hitting 3+ of the six super-effectively):"
  if weak.empty?
    puts "    none — no attacking type is SE against half the team"
  else
    weak.sort_by { |_t, n| -n }.each { |t, n| puts "    #{t.to_s.ljust(10)} #{n}/6 members" }
  end

  # ---- roles
  has = ->(list) { keys.select { |k| (meta[k][:moves] & list).any? } }
  fmt = ->(arr) { arr.empty? ? 'NONE' : arr.map { |k| meta[k][:name] }.join(', ') }
  puts "\n  ROLE AUDIT:"
  puts "    hazards        #{fmt.(has.(HAZ))}"
  puts "    hazard removal #{fmt.(has.(REM))}"
  puts "    recovery       #{fmt.(has.(REC))}"
  puts "    setup/wincon   #{fmt.(has.(SET))}"
  puts "    priority       #{fmt.(has.(PRI))}"
  puts "    phazing        #{fmt.(has.(PHZ))}"
  puts "    status/disrupt #{fmt.(has.(STAT))}"
  scarf = keys.select { |k| meta[k][:item] == 'Choice Scarf' }
  fast  = keys.count { |k| meta[k][:stats][5].to_i >= 300 }
  puts "    speed control  #{scarf.empty? ? 'no Scarf' : 'Scarf: ' + fmt.(scarf)}; #{fast}/6 at 300+ Speed"

  # ---- plan coherence
  n = Niche.classify(keys, meta)
  puts "\n  PLAN COHERENCE:"
  case n
  when 'rain', 'sun', 'sand', 'hail'
    w = Niche.weather_of(keys, meta)
    setter = meta[w[1]]
    abusers = keys.select { |k| Niche::ABUSER[n].include?(meta[k][:ability]) }
    puts "    setter: #{setter[:name]} (#{setter[:ability]}), Speed #{setter[:stats][5]}"
    puts "    abusers: #{fmt.(abusers)}"
    if n == 'rain'
      pay = abusers.select { |k| (meta[k][:moves] & RAIN_MOVES).any? }
      puts "    abusers with rain-boosted moves: #{fmt.(pay)}#{pay.length < abusers.length ? '  <-- some abusers gain nothing but Speed' : ''}"
      thund = keys.select { |k| (meta[k][:moves] & ['Thunder', 'Hurricane']).any? }
      puts "    100%-accuracy-in-rain moves: #{fmt.(thund)}"
    elsif n == 'sun'
      pay = keys.select { |k| (meta[k][:moves] & SUN_MOVES).any? }
      puts "    Fire/Solar users benefiting from sun: #{fmt.(pay)}"
    elsif n == 'sand'
      rock = keys.count { |k| meta[k][:types].include?('ROCK') }
      puts "    Rock types (free SpD x1.5 in sand): #{rock}/6"
      imm = keys.count { |k| (meta[k][:types].split('/') & %w[ROCK GROUND STEEL]).any? }
      puts "    sand-immune members: #{imm}/6#{imm < 4 ? '  <-- own sand chips ' + (6 - imm).to_s + ' of your own team' : ''}"
    end
  when 'trickroom'
    tr = keys.select { |k| meta[k][:moves].include?('Trick Room') }
    slow = keys.select { |k| meta[k][:stats][5].to_i <= 190 }
    quick = keys.select { |k| meta[k][:stats][5].to_i >= 280 }
    puts "    TR setters: #{fmt.(tr)}"
    puts "    slow enough to profit (Spe<=190): #{fmt.(slow)} (#{slow.length}/6)"
    puts "    FAST mons that TR actively hurts (Spe>=280): #{fmt.(quick)}"
  when 'stall'
    walls = keys.select { |k| (meta[k][:moves] & REC).any? }
    puts "    mons with recovery: #{fmt.(walls)} (#{walls.length}/6)"
    puts "    passive damage sources: #{fmt.(has.(HAZ) + has.(['Toxic', 'Leech Seed', 'Will-O-Wisp']))}"
    puts "    win condition: #{fmt.(has.(SET))}#{has.(SET).empty? ? '  <-- pure attrition, no wincon' : ''}"
  else
    puts "    #{keys.count { |k| (meta[k][:moves] & SET).any? }}/6 carry setup; " \
         "#{keys.count { |k| meta[k][:item] =~ /Life Orb|Choice/ }}/6 hold an offensive item"
  end
end

by_niche = st['teams'].group_by { |t| t['niche'] || Niche.classify(t['keys'], meta) }
order = by_niche.map { |k, v| [k, v.sum { |t| t['elo'] } / v.length] }.sort_by { |x| -x[1] }.map(&:first)
order.each do |nn|
  by_niche[nn].sort_by { |t| -t['elo'] }.first(PER).each do |t|
    audit("#{nn.upcase} — #{t['id']} (#{t['source']})", t['keys'], meta, t['elo'])
    puts "\n  LEAD: #{meta[t['keys'][0]][:name]} — #{t['lead_reason']}"
  end
end
