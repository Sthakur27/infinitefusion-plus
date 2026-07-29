# Read-only. Build a nickname worklist for a range of PC boxes.
#   ruby build_worklist.rb <save.rxdata> <lo_idx0> <hi_idx0> <out.json>
# Emits one entry per occupied slot in boxes lo_idx0..hi_idx0 (0-indexed, inclusive):
#   {i, box(0idx), slot(0idx), box_name, kind, display, head, body,
#    head_types, body_types, fused_types, species_raw, nick, ability, level}
# Uses stub_loader (no engine) + species_table.json. NEVER writes the save.
require_relative '../stub_loader'
require 'json'

SAVE, LO, HI, OUT = ARGV[0], ARGV[1].to_i, ARGV[2].to_i, ARGV[3]
DIR   = __dir__
TABLE = JSON.parse(File.read(File.join(DIR, '..', 'species_table.json')))

def ivg(o, n) o.instance_variable_get(n) end

# dex(String) -> table record
def rec(dex) TABLE[dex.to_s] end

def types_of(dex)
  r = rec(dex) or return []
  [r['type1'], r['type2']].compact.uniq
end

def name_of(dex)
  r = rec(dex)
  r ? r['name'] : "##{dex}"
end

save  = StubLoader.load_file(SAVE)
boxes = ivg(save[:storage_system], :@boxes)

out = []
i = 0
(LO..HI).each do |bi|
  box = boxes[bi]
  next unless box
  bname = ivg(box, :@name).to_s
  slots = ivg(box, :@pokemon) || []
  slots.each_with_index do |pk, si|
    next unless pk
    sp   = ivg(pk, :@species)
    nick = ivg(pk, :@name)                 # nil if no nickname
    abil = ivg(pk, :@ability)
    lvl  = ivg(pk, :@level)
    entry = { 'i' => i, 'box' => bi, 'slot' => si, 'box_name' => bname,
              'nick' => nick, 'ability' => (abil ? abil.to_s : nil), 'level' => lvl }
    if sp.is_a?(Symbol) && sp.to_s =~ /\AB(\d+)H(\d+)\z/
      body_dex = $1; head_dex = $2
      ht = types_of(head_dex); bt = types_of(body_dex)
      # IF fusion typing: type1 from head, type2 from body (dedup)
      fused = [ht[0], (bt[1] || bt[0])].compact.uniq
      entry.merge!(
        'kind' => 'fusion',
        'head' => name_of(head_dex), 'body' => name_of(body_dex),
        'head_types' => ht, 'body_types' => bt, 'fused_types' => fused,
        'display' => "#{name_of(head_dex)}/#{name_of(body_dex)}",
        'species_raw' => sp.to_s)
    else
      # mono species, triple fusion, or anything else we can't decode from B#H#
      dex = nil
      if sp.is_a?(Symbol)
        hit = TABLE.find { |_d, r| r['id'].to_s == sp.to_s }
        dex = hit && hit[0]
      end
      if dex
        entry.merge!('kind' => 'mono', 'display' => name_of(dex),
                     'fused_types' => types_of(dex), 'species_raw' => sp.to_s)
      else
        entry.merge!('kind' => 'other', 'display' => sp.to_s, 'species_raw' => sp.to_s)
      end
    end
    out << entry
    i += 1
  end
end

File.write(OUT, JSON.pretty_generate({ 'save' => SAVE, 'lo' => LO, 'hi' => HI,
                                        'count' => out.length, 'pokemon' => out }))
warn "worklist: #{out.length} mons from boxes idx #{LO}..#{HI} -> #{OUT}"
undecoded = out.select { |e| e['kind'] == 'other' }
warn "undecoded (kind=other): #{undecoded.length}#{undecoded.empty? ? '' : ' -> ' + undecoded.map { |e| e['species_raw'] }.uniq.first(10).join(', ')}"
