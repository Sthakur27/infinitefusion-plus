# After the fix: confirm a real API call works in the BOOTED-engine context.
require_relative 'agent_battle'   # pulls in claude_client (captures stdlib JSON early)
SimEngine.boot
$DEBUG = false
begin
  txt = ClaudeClient.complete(
    system: 'Respond ONLY with JSON.',
    user: 'Return {"action":"move","idx":2,"reason":"test \"quoted\" text"}',
    max_tokens: 80
  )
  puts "BOOTED CALL OK -> #{txt.gsub(/\s+/, ' ')}"
  puts "parsed idx -> #{ClaudeClient.json_parse(txt[/\{.*\}/m])['idx']}"
rescue => e
  puts "STILL FAILING: #{e.message}"
end
