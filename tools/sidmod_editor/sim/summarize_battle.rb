# summarize_battle.rb <battle_log.txt> [model]
#
# STANDALONE, on-demand narrative recap of ONE recorded battle (or best-of-3 series).
# Decoupled from the battle/tournament pipeline — boots no engine, just reads a turn log
# and asks Claude for a structured recap. Prints to stdout and writes <log>.summary.txt.
#
#   RB tools\sidmod_editor\sim\summarize_battle.rb sim\reports\Squads_vs_Squads3_1.txt
#
require_relative 'claude_client'

LOG   = ARGV[0] or abort "usage: summarize_battle.rb <battle_log.txt> [model]"
MODEL = ARGV[1] || "claude-sonnet-5"
abort "no such file: #{LOG}" unless File.exist?(LOG)

text  = File.read(LOG)
lines = text.lines
winner = (lines.reverse.find { |l| l =~ /WINNER:/ } || "").sub(/.*WINNER:\s*/, "").strip
turns  = lines.count { |l| l =~ /->\s/ }
games  = text.scan(/----- game \d+/).length

SYSTEM = <<~SYS
  You are an expert competitive Pokemon (Pokemon Infinite Fusion) battle analyst writing a
  tight recap of ONE battle from its turn-by-turn log. In Infinite Fusion every mon is a
  fusion of two species (combined stats/movepool/ability) and weather set by an ability is
  PERMANENT until another weather overwrites it.

  LOG FORMAT: a header naming both teams, then one line per turn:
    side0 <Nick> (<HP%>) -> <MOVE>  "<that agent's reasoning>"
  side0 = team1, side1 = team2 (written "the opposing <Nick>"). The HP% is the ACTING mon's
  current HP. Some logs are best-of-3: sections "----- game N -----" then a final WINNER.

  Judge honestly what ACTUALLY decided the game:
   - RNG: freeze/para/flinch/crit/miss streaks doing the heavy lifting.
   - BLUNDER: a player looping a useless move, setting up into a wall forever, clicking an
     immune/resisted move, or refusing to switch a sleeping/dying mon.
   - SKILL: real tactics — weather war, pivoting, priority, coverage reads, an attrition race
     won on correct math.
  Most games are a mix; name the DOMINANT factor.

  Output EXACTLY these sections, terse, referencing real nicknames and turn numbers:
  STORY: 2-3 sentences (opening -> turning point -> finish).
  KEY PLAYS: 3-6 bullets — the decisive moves/swings.
  TURNING POINT: the single moment it swung, and why.
  MVP: the one mon that carried it (say which side).
  DECIDED BY: SKILL / RNG / BLUNDER (pick the dominant one) + one sentence.
  If best-of-3, give a one-line note per game first, then summarize the series.
  No preamble, no fluff. Keep the WHOLE recap under ~230 words — one sentence per bullet.
SYS

user = "FACTS: winner=#{winner}, ~#{turns} half-turns, #{games.zero? ? 1 : games} game(s).\n\nBATTLE LOG:\n#{text}"

recap = ClaudeClient.complete(system: SYSTEM, user: user, model: MODEL, max_tokens: 2000)
# A heavy-thinking model can burn its whole budget thinking -> empty text; fall back to Haiku.
recap = ClaudeClient.complete(system: SYSTEM, user: user, model: "claude-haiku-4-5-20251001", max_tokens: 2000) if recap.to_s.strip.empty?

# Normalize fancy punctuation to ASCII so the file reads cleanly in any viewer.
recap = recap.to_s.gsub(/[—–]/, "-").gsub(/[‘’]/, "'").gsub(/[“”]/, '"').gsub("…", "...").gsub(/[→➜►]/, "->")

bar = "=" * 64
header = "#{bar}\n#{File.basename(LOG)}  |  winner: #{winner}  |  ~#{turns} half-turns" +
         (games.positive? ? "  |  #{games} games" : "") + "\n#{bar}"
out = "#{header}\n\n#{recap.strip}\n"
puts out
outfile = LOG.sub(/\.txt\z/, "") + ".summary.txt"
File.write(outfile, out)
warn "wrote #{outfile}"
