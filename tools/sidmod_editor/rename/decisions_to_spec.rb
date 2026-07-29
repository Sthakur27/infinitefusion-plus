# decisions.json -> edit spec for edit_save.rb / apply.ps1 (rename-only).
#   ruby decisions_to_spec.rb <decisions.json> <spec.json>
# Emits one {"mode":"edit","box","slot","nickname"} per RENAME. box/slot are
# 0-indexed (edit_save expects 0-indexed). nickname-only edits do NO stat recompute.
require 'json'

DEC, OUT = ARGV[0], ARGV[1]
d = JSON.parse(File.read(DEC))

pokemon = d['decisions'].select { |f| f['action'] == 'rename' && !f['new'].to_s.empty? }.map do |f|
  { 'mode' => 'edit', 'box' => f['box'], 'slot' => f['slot'], 'nickname' => f['new'] }
end

File.write(OUT, JSON.pretty_generate({ 'pokemon' => pokemon }))
warn "spec: #{pokemon.length} rename edits -> #{OUT}"
