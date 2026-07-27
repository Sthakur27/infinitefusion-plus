# sidmod: hold Xbox X (Input::ACTION) and talk to a beaten trainer to refight them.
# Works by flipping off Self-Switch A on the front event before the normal
# talk handler runs, which makes the trainer's pre-battle page fire again.
# After the battle, the event's own "Control Self-Switch A = ON" re-locks it.
#
# Limitation: only works for standard trainer events that use Self-Switch A
# as their "battled" flag. Story trainers (Rocket grunts, gym leaders, rivals,
# etc.) often use custom scripts or game variables and won't be refightable
# through this mechanism. Falls through silently for those.

class Game_Player < Game_Character
  alias sidmod_check_event_trigger_there_orig check_event_trigger_there
  def check_event_trigger_there(triggers)
    sidmod_try_refight(triggers) if Input.press?(Input::ACTION) && triggers.include?(0)
    sidmod_check_event_trigger_there_orig(triggers)
  end

  def sidmod_try_refight(triggers)
    return if $game_system.map_interpreter.running?
    new_x = @x + (@direction == 6 ? 1 : @direction == 4 ? -1 : 0)
    new_y = @y + (@direction == 2 ? 1 : @direction == 8 ? -1 : 0)
    return if !$game_map.valid?(new_x, new_y)
    map_id = $game_map.map_id
    $game_map.events.each_value do |event|
      next if !event.at_coordinate?(new_x, new_y)
      next if !triggers.include?(event.trigger)
      next if event.jumping? || event.over_trigger?
      key = [map_id, event.id, "A"]
      if $game_self_switches[key]
        $game_self_switches[key] = false
        $game_map.need_refresh = true
        event.refresh
        return
      end
    end
  end
end
