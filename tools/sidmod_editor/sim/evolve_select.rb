# Evolution phase 3/3: SELECT. Reads the parallel validation results and ADOPTS each
# changed candidate only if its win rate vs the fixed field >= its baseline (else revert).
# Writes reports/<out>/field_specs.json (the next round's field) + changelog.txt.
# No engine boot (just file reads + one JSON write).  ruby evolve_select.rb <out_tag>
require_relative 'claude_client'
require 'fileutils'

OUT_TAG = ARGV[0] or abort "usage: evolve_select.rb <out_tag>"
OUT_DIR = File.join(__dir__, 'reports', OUT_TAG)
VAL_DIR = File.join(OUT_DIR, 'val')

field = ClaudeClient::PARSE.call(File.read(File.join(OUT_DIR, 'field_in.json')))
cands = ClaudeClient::PARSE.call(File.read(File.join(OUT_DIR, 'candidates.json')))

new_field = {}
report = []
cands.each do |name, c|
  unless c["changed"]
    new_field[name] = field[name]
    report << "#{name}: no change (no structural flaw)"
    next
  end
  files = Dir[File.join(VAL_DIR, "#{name}_vs_*.txt")]
  g = files.length
  w = files.count { |f| File.read(f)[/WINNER:\s*(\S+)/, 1] == name }
  cwr = g > 0 ? w.to_f / g : 0.0
  bwr = c["baseline"].to_f
  changelog = (c["log"] || []).join("\n    ")
  if g > 0 && cwr > bwr
    new_field[name] = c["cand"]
    report << "#{name}: ADOPTED  v2 #{(cwr * 100).round}% (#{w}/#{g}) > baseline #{(bwr * 100).round}%\n    #{changelog}"
  else
    new_field[name] = field[name]
    report << "#{name}: REVERTED  v2 #{(cwr * 100).round}% (#{w}/#{g}) <= baseline #{(bwr * 100).round}% (no proven gain)\n    tried: #{changelog}"
  end
  puts report.last.lines.first.chomp
end

File.write(File.join(OUT_DIR, 'field_specs.json'), ClaudeClient::GEN.call(new_field))
File.write(File.join(OUT_DIR, 'changelog.txt'), report.join("\n\n"))
adopted = report.count { |r| r.include?(": ADOPTED") }
puts "\n=== #{adopted} adopted -> reports/#{OUT_TAG}/field_specs.json + changelog.txt ==="
