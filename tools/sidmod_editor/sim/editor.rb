# Editor agent: given a team spec + the coach's analysis, produce an IMPROVED spec.
# Validates the result and REVERTS any invalid/hallucinated mon to the original, so a
# bad edit can never corrupt the team. This is the "modify" step of the evolution loop.
require_relative 'build_team'
require_relative 'claude_client'

module Editor
  module_function

  def normalize(m)
    s = {}
    %i[head body species ability item nature].each do |k|
      v = m[k] || m[k.to_s]
      s[k] = v.to_s.upcase.gsub(/[^A-Z0-9]/, '').to_sym if v && !v.to_s.empty?
    end
    s[:moves] = (m[:moves] || m['moves'] || []).map { |x| x.to_s.upcase.gsub(/[^A-Z0-9]/, '').to_sym }
    s[:evs]   = {}
    (m[:evs] || m['evs'] || {}).each { |k, v| s[:evs][k.to_s.upcase.to_sym] = v.to_i }   # stat keys keep '_'
    s[:level] = (m[:level] || m['level'] || 100).to_i
    s
  end

  def valid_species?(sym)
    r = (GameData::Species.get(sym) rescue nil)
    r && r.id == sym                              # EXCADRILL resolves to Pikachu -> id != sym -> invalid
  end

  def valid_mon?(s)
    ok = if s[:head] || s[:body]
           valid_species?(s[:head]) && valid_species?(s[:body])
         else
           valid_species?(s[:species])
         end
    ok && (s[:moves] || []).all? { |mv| (GameData::Move.exists?(mv) rescue false) }
  end

  # Returns [validated_spec(6 mons), changelog]. Invalid new mons revert to old[i].
  # Haiku (not Sonnet) for the editor: reliable structured JSON. The smart analysis
  # is the Sonnet coach's job; the editor just executes the recommended edits.
  def evolve(team_name, old_spec, coach_rec, model: "claude-haiku-4-5-20251001")
    system = <<~SYS
      You are an elite competitive Pokemon Infinite Fusion team builder. You get a team's
      current spec (JSON) and a coach's analysis. Output a spec that fixes only the coach's
      GENUINE STRUCTURAL weaknesses (exploited by MULTIPLE opponents); IGNORE losses tagged
      pilot blunders. Prefer edits that improve the team's OWN consistency and help vs SEVERAL
      opponents over a hard counter to one team. Change AT MOST 1-2 slots. If the coach says
      "no structural change needed" (or the losses were blunders), return the team UNCHANGED -
      echo the input's 6 mons exactly. KEEP the core identity/archetype. SPECIES CLAUSE: the 6
      fusions must use DISTINCT base species - never output a fusion whose head or body species
      already appears (as head or body) on another mon of this team. Rules: exactly 6 mons;
      each fusion is head+body
      BASE species that really exist (Gen 1-5 era, prefer well-known mons; do NOT invent
      names); 4 valid moves each; valid ability/item/nature. Weather from an ability is
      permanent. Output ONLY a JSON array of 6 objects, each:
      {"head":"SPECIES","body":"SPECIES","ability":"X","item":"Y","nature":"Z","moves":["A","B","C","D"],"evs":{"HP":n,"ATTACK":n,"DEFENSE":n,"SPECIAL_ATTACK":n,"SPECIAL_DEFENSE":n,"SPEED":n}}
      (use "species":"X" instead of head/body for a non-fusion). No prose, JSON array only.
    SYS
    user = "TEAM #{team_name}\nCURRENT SPEC:\n#{ClaudeClient::GEN.call(old_spec)}\n\nCOACH ANALYSIS:\n#{coach_rec}\n\nReturn the improved 6-mon spec as a JSON array."
    txt = ClaudeClient.complete(system: system, user: user, model: model, max_tokens: 2500)
    arr = (ClaudeClient.json_parse(txt[/\[.*\]/m]) rescue nil)
    warn "[editor #{team_name}] raw #{txt.length} chars; match=#{txt[/\[.*\]/m] ? 'yes' : 'NO'}" if ENV['EDITOR_DEBUG']
    return [old_spec, ["editor returned unparseable output - team unchanged"]] unless arr.is_a?(Array) && !arr.empty?

    log = []
    validated = (0...6).map do |i|
      cand = arr[i] ? normalize(arr[i]) : nil
      if cand && valid_mon?(cand)
        old = old_spec[i]
        core = ->(s) { [s && (s[:head] || s[:species]), s && s[:body], s && s[:ability], s && s[:item], (s && s[:moves] || []).sort] }
        if old.nil? || core.(cand) != core.(old)
          log << "slot #{i}: #{old&.[](:head) || old&.[](:species)}/#{old&.[](:body)} @#{old&.[](:item)} -> #{cand[:head] || cand[:species]}/#{cand[:body]} @#{cand[:item]}  moves=#{cand[:moves].join('/')}"
        end
        cand
      else
        log << "slot #{i}: invalid edit (#{cand&.[](:head) || cand&.[](:species)}) -> kept original" if arr[i]
        old_spec[i] || cand
      end
    end.compact

    # SPECIES CLAUSE guard: revert any CHANGED mon that introduces a base species already on the team.
    base = ->(s) { (s[:head] || s[:body]) ? [s[:head], s[:body]].compact : [s[:species]].compact }
    seen = {}
    validated = validated.each_with_index.map do |s, i|
      keep = s
      if base.(s).any? { |sp| seen[sp] } && old_spec[i] && base.(s) != base.(old_spec[i])
        log << "slot #{i}: reverted (Species Clause: #{base.(s).join('/')} duplicates a teammate)"
        keep = old_spec[i]
      end
      base.(keep).each { |sp| seen[sp] = true }
      keep
    end
    [validated, log]
  end
end
