# Make every resulting nickname unique across the range.
#   ruby dedup_rename.rb <decisions.json> <decisions_out.json> [model]
# Keeps all KEPT names + the first occurrence of each new name; re-rolls later
# collisions via GPT (given the taken list). Deterministic letter-suffix fallback
# guarantees uniqueness if GPT still collides. Does NOT touch the save.
require_relative 'openai_client'
require 'json'
require 'set'

DEC, OUT = ARGV[0], ARGV[1]
MODEL = ARGV[2] || 'gpt-4o'
d = JSON.parse(File.read(DEC))
decisions = d['decisions']

def sanitize(s)
  return nil if s.nil?
  t = s.to_s.gsub(/[^A-Za-z]/, ''); return nil if t.empty?
  t = t[0, 16]; t[0].upcase + t[1..].to_s.downcase
end

# reserved starts with every name that is NOT being re-rolled: all kept currents.
reserved = Set.new
decisions.each { |f| reserved << f['current'] if f['action'] != 'rename' && f['current'] }

# Walk renames in order; first use of a name wins, later collisions get re-rolled.
need = []
decisions.each do |f|
  next unless f['action'] == 'rename'
  n = f['new']
  if n && !reserved.include?(n)
    reserved << n
  else
    need << f   # collision (with a kept name or an earlier new name)
  end
end

warn "dedup: #{need.length} mons need a fresh unique name"
if need.empty?
  File.write(OUT, JSON.pretty_generate(d)); warn "nothing to do -> #{OUT}"; exit 0
end

SYSTEM = <<~SYS
  You are the nickname-master for a Pokemon Infinite Fusion save. Give each fusion a
  cool one-word invented nickname (portmanteau of its species/typing; fantasy-monster
  vibe, like Leviatide, Cragwing, Steelwyrm, Voltghast).
  HARD RULES: letters only (A-Z/a-z), <=16 chars, capitalized, one word, pronounceable,
  not the plain species name. Each nickname MUST be UNIQUE: it must not appear in the
  provided "taken" list and must differ from every other name you return in this call.
  OUTPUT strict JSON: {"results":[{"i":<int>,"nickname":"<string>"}]}. Include every mon.
SYS

# GPT pass (up to 2 rounds); accumulate uniqueness in `reserved`.
remaining = need.dup
2.times do |round|
  break if remaining.empty?
  payload = remaining.map { |f| { 'i' => f['i'], 'fusion' => f['display'], 'types' => f['types'] } }
  user = JSON.generate({ 'taken' => reserved.to_a.sort, 'mons' => payload })
  raw = OpenAIClient.complete(system: SYSTEM, user: user, model: MODEL, max_tokens: 1500,
                              temperature: round.zero? ? 0.9 : 0.6)
  res = (JSON.parse(raw)['results'] rescue []) || []
  got = {}
  res.each { |r| got[r['i']] = sanitize(r['nickname']) }
  still = []
  remaining.each do |f|
    nn = got[f['i']]
    if nn && !reserved.include?(nn)
      f['new'] = nn; reserved << nn
    else
      still << f
    end
  end
  warn "  round #{round}: resolved #{remaining.length - still.length}, still colliding #{still.length}"
  remaining = still
end

# Deterministic fallback: append letters until unique (stays letters-only, <=16).
SUFFIX = ('a'..'z').to_a
remaining.each do |f|
  base = (sanitize(f['new']) || sanitize(f['display']) || 'Fusion')[0, 15]
  cand = base
  i = 0
  while reserved.include?(cand)
    cand = (base + SUFFIX[i % 26])[0, 16]
    cand = cand[0].upcase + cand[1..].to_s.downcase
    i += 1
    if i > 26
      base = base[0, 14]; cand = base; i = 0
    end
  end
  f['new'] = cand; reserved << cand
  warn "  fallback: #{f['display']} -> #{cand}"
end

d['renames'] = decisions.count { |f| f['action'] == 'rename' }
File.write(OUT, JSON.pretty_generate(d))
# final uniqueness assertion
alln = decisions.map { |f| f['action'] == 'rename' ? f['new'] : f['current'] }.compact
dups = alln.group_by { |n| n }.select { |_k, v| v.length > 1 }
warn "dedup done -> #{OUT}   (resulting dup names remaining: #{dups.length}#{dups.empty? ? '' : ' ' + dups.keys.join(',')})"
