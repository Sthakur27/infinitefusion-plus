# One-call API smoke test (cheap) to confirm the key + client work before a full battle.
require_relative 'claude_client'
puts "key source: " + (ENV['ANTHROPIC_API_KEY'] ? "ENV" : (File.exist?(ClaudeClient::KEYFILE) ? ".apikey file" : "NONE"))
txt = ClaudeClient.complete(
  system: 'Respond ONLY with JSON.',
  user: 'Return {"ok":true,"msg":"<3-word hello>"}',
  max_tokens: 60
)
puts "response: #{txt}"
