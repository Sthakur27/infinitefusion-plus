# worklist.json -> decisions.json, using GPT to pick good nicknames.
#   ruby gpt_rename.rb <worklist.json> <decisions.json> [model] [batch]
# For each mon GPT returns action "keep" (existing nickname is already good) or
# "rename" (junk / no nickname) + a new <=16-char nickname. Missing mons default
# to "keep" (no change = safe). This script does NOT touch the save.
require_relative 'openai_client'
require 'json'

WL, OUT = ARGV[0], ARGV[1]
MODEL   = ARGV[2] || 'gpt-4o'
BATCH   = (ARGV[3] || '25').to_i

work = JSON.parse(File.read(WL))
mons = work['pokemon']

SYSTEM = <<~SYS
  You are the official nickname-master for a Pokemon Infinite Fusion save file. You
  give Pokemon (mostly two-species FUSIONS) short, evocative, cool nicknames that fit
  the creature's component species, typing, and vibe.

  STYLE — what a GOOD nickname looks like:
  - A single invented word, usually a PORTMANTEAU blending the two species and/or the
    fusion's typing/theme. Think fantasy monster names, not jokes.
  - Real examples the owner loves (keep this energy): Leviatide, Riptide, Typhon,
    Cragwing, Sandking, Ironchomp, Mecharon, Thornmail, Bonecloak, Steelwyrm,
    Voltghast, Tidehammer, Voltario, Verdantis, Voltraqua, Aegeon, Nimbus.
  - Evokes the mon: a Water/Rock fusion -> tide/reef/crag/stone imagery; a Steel/Dragon
    -> iron/wyrm/forge imagery; a Ghost/Fire -> ember/wraith/pyre imagery; etc.

  HARD RULES for every nickname you output:
  - Letters only (A-Z, a-z). NO digits, NO spaces, NO punctuation.
  - Maximum 16 characters. Capitalized (first letter upper, rest lower is ideal).
  - Must NOT be the plain species/fusion display name itself.
  - Pronounceable and cool. One word.

  DECISION for each mon:
  - If it has NO current nickname (null): action "rename" and invent a good one.
  - If it HAS a current nickname, judge it:
      * KEEP (action "keep") if it is already a good evocative name in the style above.
      * RENAME (action "rename") if it is JUNK. Junk = box/organizer labels (e.g. Box15C,
        Team17c, Box 20), plain role/weather words (Sun, Sand, Rain, Bench, Squads),
        placeholders or memes (ur welcome, Cheater, sanic, Number 5, asdf), anything with
        digits, or just the species name. When in doubt that a name is intentional and
        cool, KEEP it.

  OUTPUT: strict JSON object, no prose:
  {"results":[{"i":<int>,"action":"keep"|"rename","nickname":"<string>"}]}
  Include EVERY mon from the input by its "i". For "keep" you may echo the current name.
  For "rename" the "nickname" field is REQUIRED and must obey the HARD RULES.
SYS

def sanitize(s)
  return nil if s.nil?
  t = s.to_s.gsub(/[^A-Za-z]/, '')          # letters only
  return nil if t.empty?
  t = t[0, 16]
  t[0].upcase + t[1..].to_s.downcase
end

decisions = {}   # i -> {action, nickname}
misses = []

mons.each_slice(BATCH).with_index do |slice, bi|
  payload = slice.map do |e|
    { 'i' => e['i'], 'fusion' => e['display'],
      'types' => (e['fused_types'] || []).join('/'),
      'ability' => e['ability'], 'current_nickname' => e['nick'] }
  end
  user = JSON.generate({ 'mons' => payload })
  raw = OpenAIClient.complete(system: SYSTEM, user: user, model: MODEL, max_tokens: 3000)
  parsed = (JSON.parse(raw) rescue nil)
  results = parsed && parsed['results']
  unless results.is_a?(Array)
    warn "batch #{bi}: unparseable response, retrying once..."
    raw = OpenAIClient.complete(system: SYSTEM, user: user, model: MODEL, max_tokens: 3000, temperature: 0.4)
    parsed = (JSON.parse(raw) rescue nil); results = parsed && parsed['results']
  end
  (results || []).each do |r|
    i = r['i']; next if i.nil?
    act = (r['action'] == 'rename') ? 'rename' : 'keep'
    nn  = sanitize(r['nickname'])
    if act == 'rename' && nn.nil?
      act = 'keep'   # invalid suggestion -> safe no-op
    end
    decisions[i] = { 'action' => act, 'nickname' => nn }
  end
  warn "batch #{bi}: #{results ? results.length : 0}/#{slice.length} results"
end

# Reconcile: every mon gets an entry; missing -> keep (no change).
final = mons.map do |e|
  i = e['i']
  d = decisions[i] || { 'action' => 'keep', 'nickname' => nil }
  misses << i unless decisions.key?(i)
  cur = e['nick']
  action = d['action']
  newnick = d['nickname']
  # Never "rename" to the same string it already is, and never rename to nil.
  if action == 'rename' && (newnick.nil? || newnick == cur)
    action = 'keep'; newnick = nil
  end
  { 'i' => i, 'box' => e['box'], 'slot' => e['slot'], 'box_name' => e['box_name'],
    'display' => e['display'], 'types' => (e['fused_types'] || []).join('/'),
    'current' => cur, 'action' => action, 'new' => newnick }
end

renames = final.count { |f| f['action'] == 'rename' }
File.write(OUT, JSON.pretty_generate({ 'model' => MODEL, 'total' => final.length,
                                       'renames' => renames, 'misses' => misses,
                                       'decisions' => final }))
warn "decisions: #{renames} renames / #{final.length} mons  (misses=#{misses.length}) -> #{OUT}"
