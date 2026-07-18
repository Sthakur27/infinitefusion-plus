# Evolution phase 1/3: PROPOSE. For each team, run the editor -> candidate v2.
# Writes reports/<out>/candidates.json (each: cand spec + changed? + editor log + baseline)
# and reports/<out>/field_in.json (the exact input field, so the parallel validators
# and the selector all agree without re-resolving SpecExtract).  READ-ONLY on the save.
#   ruby evolve_propose.rb <in_tag> [out_tag] [model]
require_relative 'teams'
require_relative 'my_team'
require_relative 'spec_extract'
require_relative 'build_team'
require_relative 'agent_battle'
require_relative 'editor'
require_relative 'claude_client'
require_relative 'roster'
require 'fileutils'
SimEngine.boot
$DEBUG = false

IN_TAG  = ARGV[0] or abort "usage: evolve_propose.rb <in_tag> [out_tag] [model]"
OUT_TAG = ARGV[1] || "#{IN_TAG}_v2"
MODEL   = ARGV[2] || "claude-haiku-4-5-20251001"
IN_DIR  = File.join(__dir__, 'reports', IN_TAG)
OUT_DIR = File.join(__dir__, 'reports', OUT_TAG)
FileUtils.mkdir_p(OUT_DIR)

field = Roster.field(IN_DIR)                      # round0 -> SpecExtract.all; later -> field_specs.json

# baseline win rates from summary.txt: "Box15A    22%  (2/9)" -> wins/games
baseline = {}
sfile = File.join(IN_DIR, 'summary.txt')
File.read(sfile).each_line { |ln| baseline[$1] = $3.to_f / [$4.to_i, 1].max if ln =~ /^\s*(\w+)\s+(\d+)%\s+\((\d+)\/(\d+)\)/ } if File.exist?(sfile)

coach_file = File.join(IN_DIR, 'recommendations.txt')
coach_text = File.exist?(coach_file) ? File.read(coach_file) : ""

sig = ->(t) { t.map { |m| [m[:head], m[:body], m[:species], m[:ability], m[:item], (m[:moves] || []).sort] } }

candidates = {}
field.each do |name, spec|
  cand, log = Editor.evolve(name, spec, coach_text, model: MODEL)
  changed = sig.(cand) != sig.(spec)
  candidates[name] = { "cand" => cand, "changed" => changed, "log" => log, "baseline" => (baseline[name] || 0.5) }
  puts "#{name}: #{changed ? 'CHANGED -> will validate' : 'no change'}"
end

File.write(File.join(OUT_DIR, 'field_in.json'),   ClaudeClient::GEN.call(field))
File.write(File.join(OUT_DIR, 'candidates.json'), ClaudeClient::GEN.call(candidates))
n = candidates.values.count { |c| c["changed"] }
puts "\n=== proposed. #{n} team(s) changed -> #{n * (field.size - 1)} validation battles queued ==="
