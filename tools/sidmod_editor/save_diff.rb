# Semantic Pokemon save diff for showcase-save updates.
#
# Matches Pokemon by owner identity + personal ID, not PC coordinates, so moving a
# Pokemon between boxes is reported as a relocation instead of remove + add.
# Usage: ruby save_diff.rb <old.rxdata> <new.rxdata> [species_table.json]

require_relative 'stub_loader'
require 'digest'
require 'json'
require 'date'

OLD_PATH, NEW_PATH = ARGV[0], ARGV[1]
abort 'usage: ruby save_diff.rb <old.rxdata> <new.rxdata> [species_table.json]' unless OLD_PATH && NEW_PATH

table_path = ARGV[2] || File.join(__dir__, 'species_table.json')
TABLE = JSON.parse(File.read(table_path))
NB = 501

def iv(object, name)
  object&.instance_variable_get(name)
end

def species_info(raw)
  body = head = nil
  text = raw.to_s
  if text =~ /\AB(\d+)H(\d+)\z/
    body = Regexp.last_match(1).to_i
    head = Regexp.last_match(2).to_i
  elsif raw.is_a?(Integer) && raw > NB
    body = raw / NB
    head = raw % NB
  end
  if body && head
    head_row = TABLE[head.to_s] || {}
    body_row = TABLE[body.to_s] || {}
    head_name = head_row['name'] || "##{head}"
    body_name = body_row['name'] || "##{body}"
    head_type = if head_row['type1'] == 'NORMAL' && head_row['type2'] == 'FLYING'
                  head_row['type2']
                else
                  head_row['type1']
                end
    body_type = if body_row['type2'].nil?
                  body_row['type1']
                elsif body_row['type2'] == head_type
                  body_row['type1']
                else
                  body_row['type2']
                end
    types = [head_type, body_type].compact.uniq.join('/')
    { display: "#{head_name}/#{body_name}", head: head_name, body: body_name, typing: types }
  else
    row = TABLE.values.find { |candidate| candidate['id'].to_s == text || candidate['dex'].to_i == raw }
    name = row&.dig('name') || text
    types = [row&.dig('type1'), row&.dig('type2')].compact.uniq.join('/')
    { display: name, head: name, body: '—', typing: types }
  end
end

def species_name(raw)
  species_info(raw)[:display]
end

def scalar(value)
  case value
  when Symbol then value.to_s
  when Hash
    value.keys.sort_by(&:to_s).to_h { |key| [key.to_s, scalar(value[key])] }
  when Array then value.map { |entry| scalar(entry) }
  else value
  end
end

def owner_key(mon)
  owner = iv(mon, :@owner)
  [iv(owner, :@name), iv(owner, :@id), iv(owner, :@public_id), iv(owner, :@secret_id)].map(&:to_s).join(':')
end

def identity_key(mon)
  pid = iv(mon, :@personalID) || iv(mon, :@personal_id)
  return "pid:#{owner_key(mon)}:#{pid}" unless pid.nil?
  # Old or unusual objects without a PID still get deterministic matching. This
  # fallback intentionally excludes location, but includes immutable-ish origin data.
  [species_name(iv(mon, :@species)), owner_key(mon), iv(mon, :@timeReceived), iv(mon, :@obtain_method),
   iv(mon, :@poke_ball), iv(mon, :@gender)].map(&:to_s).join('|')
end

def location_label(location)
  return "Party slot #{location[:slot] + 1}" if location[:kind] == :party
  "Box #{location[:box] + 1} #{location[:box_name].inspect}, slot #{location[:slot] + 1}"
end

def mon_record(mon, location)
  moves = (iv(mon, :@moves) || []).filter_map { |move| iv(move, :@id)&.to_s }
  species = species_info(iv(mon, :@species))
  {
    key: identity_key(mon),
    species: species[:display],
    head: species[:head],
    body: species[:body],
    typing: species[:typing],
    nickname: iv(mon, :@name).to_s,
    level: iv(mon, :@level),
    nature: iv(mon, :@nature)&.to_s,
    ability: iv(mon, :@ability)&.to_s,
    item: iv(mon, :@item)&.to_s,
    moves: moves,
    evs: scalar(iv(mon, :@ev) || {}),
    ivs: scalar(iv(mon, :@iv) || {}),
    shiny: scalar(iv(mon, :@shiny)),
    location: location,
    location_text: location_label(location)
  }
end

def roster(save)
  records = []
  player = save[:player]
  (iv(player, :@party) || []).each_with_index do |mon, slot|
    records << mon_record(mon, kind: :party, slot: slot) if mon
  end
  boxes = iv(save[:storage_system], :@boxes) || []
  boxes.each_with_index do |box, box_index|
    next unless box
    box_name = iv(box, :@name).to_s
    (iv(box, :@pokemon) || []).each_with_index do |mon, slot|
      records << mon_record(mon, kind: :box, box: box_index, box_name: box_name, slot: slot) if mon
    end
  end
  records
end

def index_unique(records)
  records.group_by { |record| record[:key] }
end

def semantic_signature(record)
  %i[species nickname level nature ability item moves evs ivs shiny].map { |field| record[field] }
end

def pair_records(old_records, new_records)
  old_index = index_unique(old_records)
  new_index = index_unique(new_records)
  pairs = []
  added = []
  removed = []
  (old_index.keys | new_index.keys).sort.each do |key|
    olds = (old_index[key] || []).dup
    news = (new_index[key] || []).dup

    # Cloned Pokemon can share owner + PID. Pair semantic equals first so a PC
    # relocation or insertion cannot shift every later clone into a false diff.
    olds.dup.each do |old_record|
      match_index = news.index { |new_record| semantic_signature(old_record) == semantic_signature(new_record) }
      next unless match_index
      pairs << [old_record, news.delete_at(match_index)]
      olds.delete(old_record)
    end

    olds.sort_by! { |record| [record[:species], record[:level].to_i, record[:location_text]] }
    news.sort_by! { |record| [record[:species], record[:level].to_i, record[:location_text]] }
    common = [olds.length, news.length].min
    common.times { |index| pairs << [olds[index], news[index]] }
    removed.concat(olds.drop(common))
    added.concat(news.drop(common))
  end
  [pairs, added, removed]
end

def competitive?(record)
  ev_total = record[:evs].values.map(&:to_i).sum
  record[:level].to_i == 100 && !record[:item].to_s.empty? && ev_total >= 508
end

def md(value)
  value = value.join(', ') if value.is_a?(Array)
  value = value.map { |key, item| "#{key}=#{item}" }.join(' ') if value.is_a?(Hash)
  value.to_s.gsub('|', '\\|').gsub("\n", ' ')
end

def mon_row(record)
  [record[:head], record[:body], record[:typing], record[:location_text], record[:level], record[:ability],
   record[:item].to_s.empty? ? '—' : record[:item], record[:moves].join(' / ')].map { |cell| md(cell) }
end

old_save = StubLoader.load_file(OLD_PATH)
new_save = StubLoader.load_file(NEW_PATH)
pairs, added, removed = pair_records(roster(old_save), roster(new_save))

upgraded = []
moved = []
pairs.each do |old_record, new_record|
  upgraded << [old_record, new_record] if !competitive?(old_record) && competitive?(new_record)
  moved << [old_record, new_record] unless old_record[:location] == new_record[:location]
end

old_hash = Digest::SHA256.file(OLD_PATH).hexdigest
new_hash = Digest::SHA256.file(NEW_PATH).hexdigest
puts "## #{Date.today} · Showcase save sync — #{added.length} new, #{upgraded.length} competitively upgraded"
puts "<!-- save-diff-counts:added=#{added.length} upgraded=#{upgraded.length} -->"
puts
puts "Semantic diff of `#{File.basename(OLD_PATH)}` → live `#{File.basename(NEW_PATH)}`. Pokémon are matched by owner + personal ID. The report includes only net-new identities and existing Pokémon that newly reach competitive-ready status (Lv100 + held item + at least 508 EVs). Moveset/item-only edits and #{moved.length} PC/party relocation(s) are ignored."
puts
puts "- Old SHA-256: `#{old_hash}`"
puts "- New SHA-256: `#{new_hash}`"
puts "- Roster: #{pairs.length + removed.length} → #{pairs.length + added.length} Pokémon"
puts "- Tooling: `tools/sidmod_editor/save_diff.rb` (semantic identity diff) and `tools/sidmod_editor/sync_showcase_save.ps1` (verified copy + documentation sync)."

unless added.empty?
  puts
  puts "### Added Pokémon (#{added.length})"
  puts
  puts '| Head | Body | Typing | Location | Lv | Ability | Item | Moveset |'
  puts '|---|---|---|---|---:|---|---|---|'
  added.sort_by { |record| [record[:location_text], record[:species]] }.each do |record|
    puts "| #{mon_row(record).join(' | ')} |"
  end
end

unless upgraded.empty?
  puts
  puts "### Competitively upgraded Pokémon (#{upgraded.length})"
  puts
  puts '| Head | Body | Typing | Location | Before | Competitive build |'
  puts '|---|---|---|---|---|---|'
  upgraded.sort_by { |_old, current| [current[:location_text], current[:species]] }.each do |old_record, current|
    before = "Lv#{old_record[:level]}#{old_record[:item].to_s.empty? ? '' : " @#{old_record[:item]}"}"
    build = "Lv#{current[:level]} #{current[:nature]} #{current[:ability]} @#{current[:item]} · #{current[:moves].join(' / ')}"
    puts "| #{md(current[:head])} | #{md(current[:body])} | #{md(current[:typing])} | #{md(current[:location_text])} | #{md(before)} | #{md(build)} |"
  end
end

puts
puts '### Reproduce or revert'
puts
puts '- Preview: `powershell -File tools/sidmod_editor/sync_showcase_save.ps1`'
puts '- Apply the live-save copy and append this report: `powershell -File tools/sidmod_editor/sync_showcase_save.ps1 -Apply`'
puts '- Revert the repository copy with Git; this tool never writes the live save.'
puts
puts "<!-- save-sync:#{new_hash} -->"
