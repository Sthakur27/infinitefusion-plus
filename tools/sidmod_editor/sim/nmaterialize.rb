# Materialise the ladder's best teams into empty PC boxes as playable copies.
#
#   ruby tools/sidmod_editor/sim/nmaterialize.rb <ladder_tag> <n_teams> <box_idx0,box_idx0,...>
#
# Copies are built from the LIVE mons the ladder actually tested, with full fidelity:
# ability, item, nature, level, moves, EVs AND IVs. (IVs matter — the sim battles the
# real saved Pokemon, so a copy with different IVs is not the team that was measured.)
#
# Every source slot's occupant is re-checked against the ladder's snapshot first; a
# mismatch aborts rather than silently copying whatever is there now.
require_relative 'nstore'
require_relative 'nbattle'
require_relative 'nniche'

LTAG  = ARGV[0] || 'ladder_ou4'
N     = (ARGV[1] || 10).to_i
BOXES = (ARGV[2] || '14,16').split(',').map(&:to_i)
raise 'refusing to write to in-game Box 16 (idx 15) — standing rule' if BOXES.include?(15)

NativeSim.boot!                       # LIVE save
st = NStore::PARSE.call(File.binread(File.join(NStore.dir(LTAG), 'ladder.json')))
snap = NStore.read_json(LTAG, 'pool.json')
meta = NativeSim.all_pool.each_with_object({}) { |e, h|
  d = NativeSim.describe(e[:key])
  h[e[:key]] = { moves: d[:moves], ability: d[:ability], item: d[:item], types: d[:types],
                 stats: d[:stats], bases: e[:bases].map(&:to_s), name: d[:name], species: d[:species] }
}

STATS = %i[HP ATTACK DEFENSE SPECIAL_ATTACK SPECIAL_DEFENSE SPEED]
def spec_of(key, nick)
  e = NativeSim.entry(key) or raise "key #{key} missing from live save"
  pk = e[:ref]
  s = {}
  bases = e[:bases]
  if (pk.isTripleFusion? rescue false)
    raise "#{key} is a TRIPLE fusion — add mode cannot rebuild it faithfully"
  elsif (pk.isFusion? rescue false)
    s['head'] = bases[0].to_s
    s['body'] = bases[1].to_s
  else
    s['species'] = bases[0].to_s
  end
  s['mode']     = 'add'
  s['nickname'] = nick
  s['level']    = 100
  s['ability']  = (pk.ability&.id.to_s rescue nil)
  s['item']     = (pk.item&.id.to_s rescue nil)
  s['nature']   = (pk.nature&.id.to_s rescue nil)
  s['moves']    = e[:moves].map(&:to_s)
  s['evs']      = STATS.each_with_object({}) { |x, h| v = (pk.ev[x] rescue 0); h[x.to_s] = v.to_i }
  s['ivs']      = STATS.each_with_object({}) { |x, h| v = (pk.iv[x] rescue 31); h[x.to_s] = v.to_i }
  s.reject { |_k, v| v.nil? }
end

teams = st['teams'].sort_by { |t| -t['elo'] }.first(N)
cap = BOXES.length * 30
raise "#{N} teams need #{N * 6} slots but #{BOXES.length} boxes give #{cap}" if N * 6 > cap

puts "ladder #{LTAG}: batch #{st['batch']}, materialising top #{N} of #{st['teams'].length} teams"
puts "target boxes (0-indexed): #{BOXES.join(', ')}  = in-game Box #{BOXES.map { |b| b + 1 }.join(', ')}"

# verify every source slot still holds the mon the ladder tested
drift = []
teams.each { |t| t['keys'].each { |k|
  live = meta[k] ? "#{meta[k][:name]}|#{meta[k][:species]}" : nil
  want = snap[k] ? "#{snap[k]['name']}|#{snap[k]['species']}" : nil
  drift << k if live.nil? || want.nil? || live != want } }
if drift.any?
  puts "ABORT: #{drift.uniq.length} source slots changed since the ladder snapshot: #{drift.uniq.first(8).join(', ')}"
  exit 1
end
puts "source identity check: all #{teams.sum { |t| t['keys'].length }} mons match the tested snapshot"

pokemon = []
manifest = []
teams.each_with_index do |t, i|
  niche = t['niche'] || Niche.classify(t['keys'], meta)
  box = BOXES[(i * 6) / 30]
  tag = format('%02d%s', i + 1, niche[0, 6])          # e.g. 01stall — fits the name limit
  t['keys'].each do |k|
    s = spec_of(k, tag)
    s['box'] = box
    pokemon << s
  end
  manifest << { 'rank' => i + 1, 'tag' => tag, 'id' => t['id'], 'niche' => niche,
                'elo' => t['elo'].round(1), 'source' => t['source'], 'box' => box + 1,
                'lead' => meta[t['keys'][0]][:name], 'lead_reason' => t['lead_reason'],
                'members' => t['keys'].map { |k| meta[k][:name] },
                'species' => t['keys'].map { |k| meta[k][:species] }, 'keys' => t['keys'] }
  puts "  %-8s Box%-3d Elo %-6.0f %-13s %s" %
       [tag, box + 1, t['elo'], niche, t['keys'].map { |k| meta[k][:name] }.join(', ')]
end

sf = File.join(NStore.dir(LTAG), 'materialize_spec.json')
File.binwrite(sf, NStore::GEN.call('pokemon' => pokemon))
File.binwrite(File.join(NStore.dir(LTAG), 'materialize_manifest.json'), NStore::GEN.call(manifest))
puts "\n#{pokemon.length} mons -> #{sf}"
puts "manifest -> #{File.join(NStore.dir(LTAG), 'materialize_manifest.json')}"
