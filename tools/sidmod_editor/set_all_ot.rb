# Set EVERY Pokemon's original trainer (owner) to the player.
#   ruby set_all_ot.rb <in.rxdata> <out.rxdata>
# Rewrites each party + box mon's @owner to the player's identity (id/name/gender/
# language). Clones an existing Owner object (can't call Owner.new offline - its
# initialize runs the engine's validate). Touches ONLY @owner. Verify with verify_ot.rb.
require_relative 'stub_loader'
require 'json'

IN, OUT = ARGV[0], ARGV[1]
def ivg(o, n) o.instance_variable_get(n) end
def ivs(o, n, v) o.instance_variable_set(n, v) end
def cln(o) Marshal.load(Marshal.dump(o)) end

save  = StubLoader.load_file(IN)
pl    = save[:player]
PID   = ivg(pl, :@id)
PNAME = ivg(pl, :@name)
PLANG = ivg(pl, :@language) || 2
raise 'player has no @id' if PID.nil?
raise 'player has no @name' if PNAME.nil?

def all_mons(save)
  m = []
  (ivg(save[:player], :@party) || []).each { |pk| m << pk if pk }
  (ivg(save[:storage_system], :@boxes) || []).each { |b| next unless b; (ivg(b, :@pokemon) || []).each { |pk| m << pk if pk } }
  m
end

mons = all_mons(save)
raise 'no Pokemon in save' if mons.empty?

# Infer the player's OT gender from mons already owned by this id (mode; fallback male=0).
genders = mons.map { |pk| o = ivg(pk, :@owner); (o && ivg(o, :@id) == PID) ? ivg(o, :@gender) : nil }.compact
PGENDER = genders.empty? ? 0 : genders.group_by { |g| g }.max_by { |_k, v| v.length }[0]

# Template owner to clone (prefer one already owned by the player id).
template = mons.map { |pk| ivg(pk, :@owner) }.compact.find { |o| ivg(o, :@id) == PID } || ivg(mons[0], :@owner)
raise 'no Owner object to use as template' if template.nil?

changed = 0
mons.each do |pk|
  old = ivg(pk, :@owner)
  same = old && ivg(old, :@id) == PID && ivg(old, :@name) == PNAME &&
         ivg(old, :@gender) == PGENDER && ivg(old, :@language) == PLANG
  no = cln(template)
  ivs(no, :@id, PID); ivs(no, :@name, PNAME.dup); ivs(no, :@gender, PGENDER); ivs(no, :@language, PLANG)
  ivs(pk, :@owner, no)
  changed += 1 unless same
end

Marshal.dump(save, File.open(OUT, 'wb')).close rescue File.binwrite(OUT, Marshal.dump(save))
puts JSON.generate({ 'ok' => true,
                     'player' => { 'id' => PID, 'name' => PNAME, 'gender' => PGENDER, 'language' => PLANG },
                     'total' => mons.length, 'changed' => changed, 'out' => OUT })
