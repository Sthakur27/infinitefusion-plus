require_relative 'claude_client'
tag = ARGV[0] || 'round2'
c = ClaudeClient::PARSE.call(File.read(File.join(__dir__, 'reports', tag, 'candidates.json')))
c.each do |name, h|
  next unless h['changed']
  puts "=== #{name} (baseline #{(h['baseline'].to_f * 100).round}%) ==="
  (h['log'] || []).each { |l| puts "  #{l}" }
  puts ""
end
