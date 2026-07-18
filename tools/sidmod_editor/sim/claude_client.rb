# Minimal Anthropic API client for agent-driven battles.
# Key from ENV['ANTHROPIC_API_KEY'] or the gitignored sim/.apikey file (never logged).
require 'net/http'
require 'json'
require 'uri'

module ClaudeClient
  KEYFILE = File.join(__dir__, '.apikey')
  ENDPOINT = URI("https://api.anthropic.com/v1/messages")

  # Capture the REAL stdlib JSON methods now, before the engine boots and replaces
  # JSON.generate/parse with a broken (non-escaping) version. A captured Method
  # keeps calling the original implementation even after JSON is redefined.
  GEN   = JSON.method(:generate)
  PARSE = JSON.method(:parse)

  module_function

  def json_parse(str); PARSE.call(str); end

  def key
    k = ENV['ANTHROPIC_API_KEY']
    k ||= File.read(KEYFILE).strip if File.exist?(KEYFILE)
    raise "No Anthropic API key (set ANTHROPIC_API_KEY or create sim/.apikey)" if k.nil? || k.empty?
    k
  end

  def complete(system:, user:, model: "claude-haiku-4-5-20251001", max_tokens: 400)
    http = Net::HTTP.new(ENDPOINT.host, ENDPOINT.port)
    http.use_ssl = true
    http.read_timeout = 240
    req = Net::HTTP::Post.new(ENDPOINT)
    req['x-api-key'] = key
    req['anthropic-version'] = '2023-06-01'
    req['content-type'] = 'application/json'
    req.body = GEN.call({
      model: model, max_tokens: max_tokens, system: system,
      messages: [{ role: "user", content: user }]
    })
    attempts = 0
    loop do
      attempts += 1
      begin
        res = http.request(req)
        if %w[429 500 502 503 529].include?(res.code) && attempts < 6
          sleep([2**attempts, 30].min); next    # rate limit / transient -> backoff + retry
        end
        raise "Anthropic API #{res.code}: #{res.body.to_s[0, 300]}" unless res.code == "200"
        # Skip leading "thinking" content blocks; return the first text block.
        blocks = PARSE.call(res.body)["content"] || []
        tb = blocks.find { |b| b["type"] == "text" }
        return (tb && tb["text"]).to_s
      rescue Net::ReadTimeout, Net::OpenTimeout, Errno::ECONNRESET, SocketError, EOFError
        raise if attempts >= 6
        sleep([2**attempts, 30].min)
      end
    end
  end

  def complete_raw(**kw)  # kept for debugging
    complete(**kw)
  end
end
