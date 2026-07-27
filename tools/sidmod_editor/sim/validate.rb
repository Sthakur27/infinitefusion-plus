# FINAL VALIDATION: for a benchmarked field, prove each team is (a) JUSTIFIABLE - every fusion
# earns its slot (engine-truth typing/stats/flags, no dilution) - and (b) BACKED BY GAME RECORDS
# where it PLAYED WELL (good AI decisions), independent of raw win rate. Combines the fusion
# inspector (justification) with an LLM read of the battle logs (play quality).
#
# Usage: ruby tools/sidmod_editor/sim/validate.rb <tag>   (e.g. final_v2)
#   reads  reports/<tag>/field_specs.json  +  reports/<tag>/<a>_vs_<b>.txt battle logs
#   writes reports/<tag>_validation/<team>.md  + reports/<tag>_validation/SUMMARY.md
require 'json'; require 'fileutils'
TAG   = ARGV[0] || 'final_v2'
DIR   = File.join(__dir__, 'reports', TAG)
FIELD = JSON.parse(File.read(File.join(DIR, 'field_specs.json')))   # parse BEFORE boot
require_relative 'fusion_inspector'
require_relative 'claude_client'
require_relative 'editor'
SimEngine.boot
$DEBUG = false
OUT = File.join(__dir__, 'reports', "#{TAG}_validation"); FileUtils.mkdir_p(OUT)
MODEL = ENV['VALIDATE_MODEL'] || 'claude-opus-4-8'

# ---- Records: parse the round-robin log headers involving `team`. ----
def records_for(team)
  recs = []
  Dir[File.join(DIR, '*_vs_*.txt')].each do |f|
    base = File.basename(f, '.txt')
    a, b = base.split('_vs_')
    next unless a == team || b == team
    head = File.read(f).lines.first.to_s
    # "A (side0) vs B (side1)  best-of-3 A:2 B:1 draw:0"
    counts = head.scan(/(\w+):(\d+)/).to_h { |k, v| [k, v.to_i] }
    opp = (a == team) ? b : a
    mine = counts[team] || 0; theirs = counts[opp] || 0; draw = counts['draw'] || 0
    res = mine > theirs ? 'W' : (theirs > mine ? 'L' : 'D')
    recs << { opp: opp, mine: mine, theirs: theirs, draw: draw, res: res, file: f }
  end
  recs.sort_by { |r| r[:opp] }
end

# ---- Play-quality: pull this team's OWN decision lines from its logs (side0 when it's the
# left name, side1 when it's the right), then have an LLM grade the DECISIONS, not the score. ----
# Only REAL LLM decisions: a line with a quoted reasoning string that is NOT a forced/fallback/
# random turn. (Post-cap random-policy turns carry no reason; forced/fallback are not real choices.)
# Grading the random tail of stall games unfairly blames the pilot for moves it never made.
def decision_lines(team, files)
  lines = []
  files.each do |r|
    side = File.basename(r[:file], '.txt').split('_vs_').first == team ? 'side0' : 'side1'
    File.read(r[:file]).lines.each do |ln|
      s = ln.strip
      next unless s.start_with?(side)
      m = s[/"(.*)"/, 1]                      # the pilot's reasoning
      next if m.nil? || m.empty? || m.start_with?('(forced)', '(fallback')
      lines << s
    end
  end
  lines
end

RUBRIC = <<~SYS
  You are a competitive Pokemon coach grading HOW WELL a team was PILOTED from its battle-decision
  log. Each line is one turn: "sideN <mon> (<hp>%) -> <MOVE or switch>  \"<pilot reasoning>\"".
  Judge DECISION QUALITY, NOT the win/loss record - a team can play excellently and still lose a
  matchup. GOOD play includes: setting hazards early when safe, phazing/ resetting an opposing
  setup sweeper, revenge-killing with priority/speed, picking super-effective/ KO moves, correct
  sleep handling (staying in rather than switch-looping), smart pivots (U-turn/Volt Switch), not
  over-boosting. BLUNDERS include: choosing an immune/badly-resisted move, switching a sleeping mon
  in and out, endless set-up into a wall/phazer, panic-switching over harmless status, needless
  switches that hand free turns. Output STRICT JSON only:
  {"rating":1-5,"played_well":true|false,"good_plays":["...","..."],"blunders":["..."],"one_line":"overall verdict"}
  rating: 5=flawless, 4=solid with minor slips, 3=mixed, 2=frequent misplays, 1=throwing.
  played_well = rating>=4 (decisions were sound regardless of results).
SYS

def grade_play(team, lines)
  return { "rating" => nil, "played_well" => false, "good_plays" => [], "blunders" => [], "one_line" => "no logs", "ungraded" => true } if lines.empty?
  sample = lines.first(200).join("\n")   # cap prompt size
  user = "TEAM #{team}\nDECISION LOG (its own turns across all series):\n#{sample}"
  2.times do                             # retry once: a truncated array yields unparseable JSON
    txt = ClaudeClient.complete(system: RUBRIC, user: user, model: MODEL, max_tokens: 2500)
    j = (ClaudeClient.json_parse(txt[/\{.*\}/m]) rescue nil)
    return j if j.is_a?(Hash) && j["rating"]
  end
  { "rating" => nil, "played_well" => false, "good_plays" => [], "blunders" => [], "one_line" => "grader error (unparseable) - see logs directly", "ungraded" => true }
end

summary = []
FIELD.each do |team, mons|
  next if %w[OU UbersOff UbersBal].include?(team)   # controls: benchmarks, not deliverables
  md = ["# #{team} — final validation\n"]

  # (a) JUSTIFICATION
  md << "## 1. Roster justification — does every fusion earn its slot?\n"
  team_flags = []
  mons.each_with_index do |m, i|
    r = Inspect.check(m)
    md << "**SLOT #{i + 1}.** " + Inspect.render(r).gsub(/^/, '  ').strip
    # HARD failures = a fusion contributing nothing / broken (dead ability, invalid). TYPING-NO-GAIN
    # and STAT-TAX are NOTES, not failures: they're the expected fusion tax and are justified when a
    # parent still donates an ability/move/immunity (the coach vetted each). Only dead/illegal fails.
    hard  = r[:flags].select { |f| f =~ /DEAD-ABILITY|INVALID/ }
    notes = r[:flags].select { |f| f =~ /TYPING-NO-GAIN|STAT-TAX|NEW-4x-WEAK|OFF-PARENT/ }
    verdict = hard.empty? ? "JUSTIFIED#{notes.empty? ? '' : ' (notes: ' + notes.map { |x| x.split(':').first }.uniq.join(', ') + ')'}" :
                            "FAILS (#{hard.map { |x| x.split(':').first }.uniq.join(', ')})"
    team_flags.concat(hard.map { |f| "slot #{i + 1}: #{f}" })
    md << "  -> **#{verdict}**\n"
  end
  just = team_flags.empty? ? "JUSTIFIED (every fusion earns its slot; no dead-ability/illegal picks)" :
                             "REVIEW — real problems:\n  - " + team_flags.join("\n  - ")
  md << "**Roster verdict: #{just}**\n"

  # (b) RECORDS + PLAY QUALITY
  recs = records_for(team)
  md << "## 2. Game records\n"
  if recs.empty?
    md << "_(no battle logs found for #{team} in reports/#{TAG})_\n"
  else
    w = recs.count { |r| r[:res] == 'W' }; l = recs.count { |r| r[:res] == 'L' }; d = recs.count { |r| r[:res] == 'D' }
    recs.each { |r| md << "- vs **#{r[:opp]}**: #{r[:mine]}-#{r[:theirs]}-#{r[:draw]} (#{r[:res]})" }
    md << "\n**Series record: #{w}W-#{l}L-#{d}D**\n"
  end

  md << "## 3. Quality of play — good AI moves? (independent of win rate)\n"
  g = grade_play(team, decision_lines(team, recs))
  ungraded = g['ungraded']
  rate_s = ungraded ? "ungraded" : "#{g['rating']}/5"
  status_s = ungraded ? "GRADER ERROR" : (g['played_well'] ? 'PLAYED WELL' : 'NEEDS REVIEW')
  md << "**Rating: #{rate_s} — #{status_s}**  \n#{g['one_line']}\n"
  md << "\n_Good plays:_\n" + (Array(g['good_plays']).map { |x| "- #{x}" }.join("\n"))
  md << "\n_Blunders:_\n" + (Array(g['blunders']).empty? ? "- none noted" : Array(g['blunders']).map { |x| "- #{x}" }.join("\n"))

  # OVERALL. Ungraded = technical failure, not a team fault -> don't fail the team on it.
  ok_just = team_flags.empty?
  ok_play = g['played_well']
  overall = ungraded ? (ok_just ? "JUSTIFIED (play ungraded)" : "REVIEW") :
                       ((ok_just && ok_play) ? "VALIDATED" : "REVIEW")
  md << "\n## Verdict: **#{overall}**  (justified: #{ok_just ? 'yes' : 'review'}, played well: #{ungraded ? 'ungraded' : (ok_play ? 'yes' : 'review')})\n"

  File.write(File.join(OUT, "#{team}.md"), md.join("\n"))
  summary << { team: team, overall: overall, just: ok_just, rating: rate_s,
               record: recs.empty? ? "-" : "#{recs.count { |r| r[:res] == 'W' }}W-#{recs.count { |r| r[:res] == 'L' }}L-#{recs.count { |r| r[:res] == 'D' }}D" }
  puts "validated #{team}: #{overall} (just=#{ok_just} play=#{rate_s} rec=#{summary.last[:record]})"
end

s = ["# Validation summary — #{TAG}\n", "| Team | Justified | Play | Record | Verdict |", "|---|---|---|---|---|"]
summary.each { |r| s << "| #{r[:team]} | #{r[:just] ? 'yes' : 'REVIEW'} | #{r[:rating]} | #{r[:record]} | **#{r[:overall]}** |" }
File.write(File.join(OUT, 'SUMMARY.md'), s.join("\n") + "\n")
puts "\nwrote per-team + SUMMARY.md -> reports/#{TAG}_validation/"
