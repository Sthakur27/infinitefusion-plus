# One worker process: boots the engine ONCE, then runs its whole shard of games.
#   ruby nworker.rb <shard.tsv> <out.tsv>
# shard.tsv rows: gid \t a_keys(csv) \t b_keys(csv) \t seed
# Appends one games.tsv row per game; flushes as it goes so a kill loses ~nothing
# and the shard can be resumed (already-finished gids are skipped).
require 'set'
require_relative 'nstore'
require_relative 'nbattle'

shard, out = ARGV[0], ARGV[1]
jobs = NStore.read_jobs(shard)
done = File.exist?(out) ? File.readlines(out).map { |l| l.split("\t", 2)[0] }.to_set : Set.new
NativeSim.boot!
f = File.open(out, 'ab')
n = 0
jobs.each do |gid, a, b, seed|
  next if done.include?(gid)
  r = NativeSim.run(a, b, seed: seed)
  f.write(NStore.row(gid, a.join(','), b.join(','), seed, r) + "\n")
  n += 1
  f.flush if n % 25 == 0
end
f.flush; f.close
warn "worker #{File.basename(shard)}: #{n} games"
