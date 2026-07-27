# Parallel matchup runner. Shards every bo-N job into N seeded SINGLE-GAME jobs and fans them ALL
# out across CPU cores (throttled), then re-aggregates by label. This uses every core (a 12-matchup
# bo3 sweep = 36 parallel games, not 12 serial series).  ruby prun.rb <jobs.json> [out_tag]
# jobs.json = array of job hashes (see matchup_worker.rb). Each job's 'games' becomes N game-jobs.
# Each worker is its own process (the engine uses process-global state, so threads aren't safe).
require 'json'; require 'etc'; require 'fileutils'; require 'tmpdir'
RAW  = JSON.parse(File.read(ARGV[0]))
TAG  = ARGV[1] || 'prun'
DIR  = __dir__
GAMEROOT = File.expand_path(File.join(DIR, '..', '..', '..'))
WORKER   = File.join(DIR, 'matchup_worker.rb')
RB       = File.join(RbConfig::CONFIG['bindir'], RbConfig::CONFIG['ruby_install_name']) + RbConfig::CONFIG['EXEEXT']
THROTTLE = [Etc.nprocessors - 2, 1].max
TMP = File.join(Dir.tmpdir, "prun_#{TAG}_#{Process.pid}"); FileUtils.mkdir_p(TMP)

# Expand each job into N seeded single-game jobs (seeds 1..N match the old series ordering).
JOBS = []
RAW.each do |j|
  n = (j['games'] || 1).to_i
  n = 1 if n < 1
  n.times { |g| JOBS << j.merge('seed' => g + 1, 'games' => 1) }   # 'label' kept for grouping
end
LABELS = RAW.map { |j| j['label'] }   # preserve input order for the summary

queue   = JOBS.each_with_index.to_a
running = {}                          # pid => [idx, outfile, label]
agg     = Hash.new { |h, k| h[k] = [0, 0, 0] }   # label => [a, b, draw]
logs    = Hash.new { |h, k| h[k] = [] }

puts "prun: #{RAW.length} matchups -> #{JOBS.length} game-jobs, #{THROTTLE} at a time (#{Etc.nprocessors} cores)"
until queue.empty? && running.empty?
  while running.size < THROTTLE && !queue.empty?
    job, idx = queue.shift
    jobfile = File.join(TMP, "job_#{idx}.json")
    outfile = File.join(TMP, "res_#{idx}.txt")
    logfile = File.join(TMP, "w_#{idx}.log")
    job['out'] = outfile
    File.write(jobfile, JSON.generate(job))
    pid = Process.spawn(RB, WORKER, jobfile, chdir: GAMEROOT, %i[out err] => logfile)
    running[pid] = [idx, outfile, job['label']]
  end
  pid = Process.wait
  idx, outfile, label = running.delete(pid)
  if outfile && File.exist?(outfile) && !File.read(outfile).strip.empty?
    lbl, a, b, dr = File.read(outfile).strip.split("\t")
    agg[lbl][0] += a.to_i; agg[lbl][1] += b.to_i; agg[lbl][2] += dr.to_i
    logs[lbl] << File.read(outfile + '.log') if File.exist?(outfile + '.log')
    print "."; $stdout.flush
  else
    puts "\n  FAILED game-job #{idx} (#{label}) — see #{File.join(TMP, "w_#{idx}.log")}"
  end
end

puts "\n\n=== RESULTS (#{TAG}) — games won-lost-drawn ==="
LABELS.each do |lbl|
  a, b, dr = agg[lbl]
  res = a > b ? 'W' : (b > a ? 'L' : 'D')
  puts "  #{lbl.to_s.ljust(24)} #{a}-#{b}-#{dr}  (#{res})"
end
outdir = File.join(DIR, 'reports', TAG); FileUtils.mkdir_p(outdir)
LABELS.each do |lbl|
  a, b, dr = agg[lbl]
  File.write(File.join(outdir, "#{lbl.to_s.gsub(/[^\w.-]/, '_')}.txt"),
             "#{lbl} #{a}-#{b}-#{dr}\n\n" + logs[lbl].join("\n\n"))
end
puts "logs -> #{outdir}"
puts "DONE"
