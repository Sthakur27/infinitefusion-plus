# Result storage for the native-AI search. Plain files, append-only, resumable,
# analyzable long after the run. One directory per run:
#
#   sim/nreports/<tag>/
#     manifest.json   run config: tier, clauses, phase params, pool digest, timings
#     pool.json       snapshot of every pool mon (key -> set/stats/roles) so old
#                     results stay interpretable even after the save changes
#     teams.tsv       team_id \t source \t key1,..,key6
#     jobs.tsv        gid \t a_keys \t b_keys \t seed          (exact games requested)
#     games.tsv       one row per finished game (see COLS) — the fact table
#     ratings.csv     derived: per-mon appearances/winrate/KOs/coef
#     teams_rank.csv  derived: per-team record
#     report.md       human summary
#
# TSV, not JSON, for the big tables: the engine monkeypatches JSON.generate (it
# fails to escape quotes) and TSV appends are crash-safe + trivially resumable.
require 'fileutils'
require 'json'
module NStore
  # stdlib JSON captured BEFORE the engine boots (engine patches parse to
  # symbolize keys and generate to a broken escaper)
  GEN   = JSON.method(:generate)
  PARSE = JSON.method(:parse)

  COLS = %w[gid team_a team_b seed winner turns a_alive b_alive
            a_kos b_kos a_faint b_faint a_hp b_hp].freeze

  module_function

  def dir(tag); File.join(__dir__, 'nreports', tag); end

  def init(tag)
    d = dir(tag); FileUtils.mkdir_p(d); d
  end

  def write_json(tag, name, obj)
    File.binwrite(File.join(dir(tag), name), GEN.call(obj))
  end

  def read_json(tag, name)
    PARSE.call(File.binread(File.join(dir(tag), name)))
  end

  def write_pool(tag, entries)
    h = {}
    entries.each do |e|
      d = NativeSim.describe(e[:key])
      h[e[:key]] = { 'name' => d[:name], 'species' => d[:species], 'box' => d[:box], 'slot' => d[:slot],
                     'types' => d[:types], 'ability' => d[:ability], 'nature' => d[:nature],
                     'item' => d[:item], 'moves' => d[:moves], 'evs' => d[:evs], 'stats' => d[:stats],
                     'roles' => d[:roles], 'ou' => d[:ou], 'bases' => e[:bases].map(&:to_s) }
    end
    write_json(tag, 'pool.json', h)
  end

  def write_teams(tag, teams)   # teams: {team_id => {source:, keys:[]}}
    File.binwrite(File.join(dir(tag), 'teams.tsv'),
                  teams.map { |id, t| "#{id}\t#{t[:source]}\t#{t[:keys].join(',')}" }.join("\n") + "\n")
  end

  def read_teams(tag)
    File.readlines(File.join(dir(tag), 'teams.tsv')).map { |l|
      id, src, keys = l.chomp.split("\t"); [id, { source: src, keys: keys.split(',') }]
    }.to_h
  end

  def write_jobs(tag, jobs)     # jobs: [[gid, a_keys, b_keys, seed], ...]
    File.binwrite(File.join(dir(tag), 'jobs.tsv'),
                  jobs.map { |g, a, b, s| "#{g}\t#{a.join(',')}\t#{b.join(',')}\t#{s}" }.join("\n") + "\n")
  end

  def read_jobs(path)
    File.readlines(path).map { |l|
      g, a, b, s = l.chomp.split("\t")
      [g, a.split(','), b.split(','), s.to_i]
    }
  end

  # One result row. Per-mon vectors are '|'-joined, positional with the team's keys.
  def row(gid, ta, tb, seed, r)
    v = ->(side, f) { r[side].map { |m| f.call(m) }.join('|') }
    [gid, ta, tb, seed, r[:winner], r[:turns], r[:a_alive], r[:b_alive],
     v.(:a, ->(m) { m[:kos] }), v.(:b, ->(m) { m[:kos] }),
     v.(:a, ->(m) { m[:fainted] ? 1 : 0 }), v.(:b, ->(m) { m[:fainted] ? 1 : 0 }),
     v.(:a, ->(m) { '%.2f' % m[:hp] }), v.(:b, ->(m) { '%.2f' % m[:hp] })].join("\t")
  end

  def read_games(path)
    File.readlines(path).map { |l|
      f = l.chomp.split("\t")
      next nil if f.length < COLS.length
      { gid: f[0], team_a: f[1], team_b: f[2], seed: f[3].to_i, winner: f[4].to_sym,
        turns: f[5].to_i, a_alive: f[6].to_i, b_alive: f[7].to_i,
        a_kos: f[8].split('|').map(&:to_i), b_kos: f[9].split('|').map(&:to_i),
        a_faint: f[10].split('|').map(&:to_i), b_faint: f[11].split('|').map(&:to_i),
        a_hp: f[12].split('|').map(&:to_f), b_hp: f[13].split('|').map(&:to_f) }
    }.compact
  end
end
