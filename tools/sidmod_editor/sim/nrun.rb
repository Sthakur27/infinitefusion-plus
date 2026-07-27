# Parallel driver for native-AI games. Splits a job list across (cores-2) worker
# PROCESSES (the engine keeps process-global state, so not threads), each of which
# boots once and grinds its shard, then concatenates the shards into games.tsv.
#
#   NRun.execute(tag, jobs)  -> path to games.tsv   (jobs: [[gid, aKeys, bKeys, seed], ...])
#   ruby nrun.rb <tag> <jobs.tsv> [workers]         (standalone)
#
# Resumable: shard outputs are kept, and a re-run skips gids already present.
require 'etc'
require 'fileutils'
require_relative 'nstore'

module NRun
  module_function

  RB       = File.join(RbConfig::CONFIG['bindir'], RbConfig::CONFIG['ruby_install_name']) + RbConfig::CONFIG['EXEEXT']
  WORKER   = File.join(__dir__, 'nworker.rb')
  GAMEROOT = File.expand_path(File.join(__dir__, '..', '..', '..'))   # engine boots from game root

  def workers; [Etc.nprocessors - 2, 1].max; end

  def execute(tag, jobs, nw = workers, quiet: false)
    d = NStore.init(tag)
    sh = File.join(d, 'shards'); FileUtils.mkdir_p(sh)
    nw = [nw, jobs.length].min
    nw = 1 if nw < 1
    shards = Array.new(nw) { [] }
    jobs.each_with_index { |j, i| shards[i % nw] << j }
    t0 = Time.now
    pids = {}
    shards.each_with_index do |part, i|
      next if part.empty?
      sf = File.join(sh, "shard_#{i}.tsv"); of = File.join(sh, "out_#{i}.tsv")
      NStore.write_jobs_to(sf, part)
      lf = File.join(sh, "w_#{i}.log")
      pids[Process.spawn(RB, WORKER, sf, of, chdir: GAMEROOT, %i[out err] => lf)] = [i, of, lf]
    end
    fails = []
    until pids.empty?
      pid, st = Process.wait2
      i, of, lf = pids.delete(pid)
      fails << [i, lf] if !st.success? || !File.exist?(of)
      print '.' unless quiet
      $stdout.flush
    end
    games = File.join(d, 'games.tsv')
    File.open(games, 'wb') do |out|
      Dir[File.join(sh, 'out_*.tsv')].sort.each { |f| out.write(File.binread(f)) }
    end
    n = File.readlines(games).length
    unless quiet
      puts "\n#{n}/#{jobs.length} games in %.1fs (%.1f games/s, %d workers)" %
           [Time.now - t0, n / (Time.now - t0), nw]
      fails.each { |i, lf| puts "  FAILED shard #{i} -> #{lf}" }
    end
    games
  end
end

# NStore helper used above (write an arbitrary jobs list to a path)
module NStore
  module_function
  def write_jobs_to(path, jobs)
    File.binwrite(path, jobs.map { |g, a, b, s| "#{g}\t#{a.join(',')}\t#{b.join(',')}\t#{s}" }.join("\n") + "\n")
  end
end

if $PROGRAM_NAME == __FILE__ && ARGV.length >= 2
  NRun.execute(ARGV[0], NStore.read_jobs(ARGV[1]), (ARGV[2] || NRun.workers).to_i)
end
