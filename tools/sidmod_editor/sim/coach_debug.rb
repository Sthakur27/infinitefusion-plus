require_relative 'engine'
require_relative 'claude_client'
SimEngine.boot
$DEBUG = false
require 'net/http'; require 'uri'
summary = File.read(File.join(__dir__, 'reports', 'summary.txt'))
sample  = File.read(File.join(__dir__, 'reports', 'Sun_vs_Rain_1.txt'))

system = "You are a competitive Pokemon coach. Give terse per-team recommendations."
user = "TOURNAMENT RESULTS\n#{summary}\n\nSAMPLE BATTLE LOGS\n#{sample}"

uri = URI("https://api.anthropic.com/v1/messages")
http = Net::HTTP.new(uri.host, uri.port); http.use_ssl = true; http.read_timeout = 120
req = Net::HTTP::Post.new(uri)
req['x-api-key'] = ClaudeClient.key
req['anthropic-version'] = '2023-06-01'; req['content-type'] = 'application/json'
req.body = ClaudeClient::GEN.call({ model: "claude-sonnet-5", max_tokens: 2500, system: system,
                                    messages: [{ role: "user", content: user }] })
res = http.request(req)
puts "HTTP #{res.code}"
puts "BODY[0,600]: #{res.body[0,600]}"
