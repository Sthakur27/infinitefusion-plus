# Fire several rapid calls to reproduce the battle 400 and print the full body.
require_relative 'claude_client'
ok = 0
8.times do |n|
  begin
    ClaudeClient.complete(system: 'Respond ONLY with JSON.', user: 'Return {"n":' + n.to_s + '}', max_tokens: 40)
    ok += 1
    print "."
  rescue => e
    puts "\ncall #{n} FAILED: #{e.message}"
  end
end
puts "\n#{ok}/8 succeeded"
