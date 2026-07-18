# Loads Sid's 5 teams from a save (read-only) as real battle-ready Pokemon.
require_relative 'battle'

module SimTeams
  module_function

  DEFAULT_SAVE = File.join(ENV['APPDATA'], 'infinitefusion', 'File A.rxdata')

  # Returns { name => [Pokemon x6] } using the real engine's Pokemon objects.
  # READ-ONLY: never writes the save. 3 weather teams + 3 "Squads" legendary teams
  # (box 34="Squads 3"/idx33, 35="Squads  2"/idx34, 36="Squads"/idx35; first 6 each).
  def load(save_path = DEFAULT_SAVE)
    save    = StubLoader.load_file(save_path)
    party   = save[:player].party.compact
    storage = save[:storage_system]
    box     = ->(idx, n = 6) { (0...30).map { |i| storage[idx, i] }.compact[0, n] }
    box31   = box.(30, 12)
    box15   = box.(14, 18)   # 3 AI-made teams (box index 14): legends A/B + non-legendary bulky
    {
      "Sun"     => party[0, 6],
      "Rain"    => box31[0, 6],
      "Sand"    => box31[6, 6],
      "Squads"  => box.(35),
      "Squads2" => box.(34),
      "Squads3" => box.(33),
      "Box15A"  => box15[0, 6],
      "Box15B"  => box15[6, 6],
      "Box15C"  => box15[12, 6],
    }
  end

  def clone(team); team.map { |p| Marshal.load(Marshal.dump(p)) }; end
end
