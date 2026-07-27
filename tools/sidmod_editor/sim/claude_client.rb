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

  # thinking defaults to DISABLED: complete() is for fast structured (usually JSON) outputs, and
  # models that adaptively think (Sonnet 5, Opus 4.8) otherwise spend the whole max_tokens budget
  # thinking and return an EMPTY text block. Callers that want thinking use complete_tools instead.
  # cache: true marks the (large, static) system prompt with cache_control so Anthropic prompt-caching
  # serves it from cache on every subsequent call in a run - big cost + time-to-first-token win, zero
  # behaviour change. Only worthwhile when `system` is long (>~1-2k tokens) and reused, e.g. the pilot.
  def complete(system:, user:, model: "claude-haiku-4-5-20251001", max_tokens: 400, thinking: { type: "disabled" }, cache: false)
    http = Net::HTTP.new(ENDPOINT.host, ENDPOINT.port)
    http.use_ssl = true
    http.read_timeout = 240
    req = Net::HTTP::Post.new(ENDPOINT)
    req['x-api-key'] = key
    req['anthropic-version'] = '2023-06-01'
    req['content-type'] = 'application/json'
    sys = cache ? [{ type: "text", text: system, cache_control: { type: "ephemeral" } }] : system
    body = { model: model, max_tokens: max_tokens, system: sys,
             messages: [{ role: "user", content: user }] }
    body[:thinking] = thinking if thinking
    req.body = GEN.call(body)
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

  # Low-level single POST returning the FULL parsed response (content blocks + stop_reason).
  def post(body, headers: {})
    http = Net::HTTP.new(ENDPOINT.host, ENDPOINT.port)
    http.use_ssl = true
    http.read_timeout = 300
    req = Net::HTTP::Post.new(ENDPOINT)
    req['x-api-key'] = key
    req['anthropic-version'] = '2023-06-01'
    req['content-type'] = 'application/json'
    headers.each { |k, v| req[k] = v }
    req.body = GEN.call(body)
    attempts = 0
    loop do
      attempts += 1
      begin
        res = http.request(req)
        if %w[429 500 502 503 529].include?(res.code) && attempts < 6
          sleep([2**attempts, 30].min); next
        end
        raise "Anthropic API #{res.code}: #{res.body.to_s[0, 300]}" unless res.code == "200"
        return PARSE.call(res.body)
      rescue Net::ReadTimeout, Net::OpenTimeout, Errno::ECONNRESET, SocketError, EOFError
        raise if attempts >= 6
        sleep([2**attempts, 30].min)
      end
    end
  end

  # Agentic tool-use loop. `tools` = array of tool schemas; `executor` = a proc that takes
  # (tool_name, input_hash) and returns a String result. Runs until the model stops asking for
  # tools (or max_rounds). Returns [final_text, transcript_of_messages]. The block is required.
  # thinking_budget > 0 enables extended thinking (budget_tokens); requires max_tokens > budget.
  # With thinking on, assistant turns start with a signed thinking block that MUST be echoed back
  # verbatim on the next request - we store the full `blocks` array, so that is preserved.
  def complete_tools(system:, user:, tools:, model: "claude-opus-4-8", max_tokens: 16000,
                     max_rounds: 24, thinking_budget: 10000, effort: "high")
    messages = [{ role: "user", content: user }]
    headers = {}
    body_extra = {}
    if thinking_budget && thinking_budget > 0
      # Opus 4.8+ uses adaptive thinking + output_config.effort (not the legacy budget_tokens API).
      body_extra[:thinking] = { type: "adaptive" }
      body_extra[:output_config] = { effort: effort }
    end
    rounds = 0
    loop do
      rounds += 1
      resp = post({ model: model, max_tokens: max_tokens, system: system, tools: tools,
                    messages: messages, **body_extra }, headers: headers)
      blocks = resp["content"] || []
      messages << { role: "assistant", content: blocks }
      tool_uses = blocks.select { |b| b["type"] == "tool_use" }
      if tool_uses.empty? || resp["stop_reason"] != "tool_use" || rounds >= max_rounds
        text = blocks.select { |b| b["type"] == "text" }.map { |b| b["text"] }.join("\n").strip
        return [text, messages]
      end
      results = tool_uses.map do |tu|
        out = begin
          yield(tu["name"], tu["input"] || {})
        rescue => e
          "ERROR: #{e.class}: #{e.message}"
        end
        { type: "tool_result", tool_use_id: tu["id"], content: out.to_s }
      end
      messages << { role: "user", content: results }
    end
  end
end
