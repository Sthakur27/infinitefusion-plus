# Minimal OpenAI Chat Completions client (JSON mode).
# Key from ENV['OPENAI_API_KEY'] or the gitignored sim/.openaiapikey file (never logged).
require 'net/http'
require 'json'
require 'uri'

module OpenAIClient
  KEYFILE  = File.join(__dir__, '..', 'sim', '.openaiapikey')
  ENDPOINT = URI('https://api.openai.com/v1/chat/completions')

  module_function

  def key
    k = ENV['OPENAI_API_KEY']
    k ||= File.read(KEYFILE).strip if File.exist?(KEYFILE)
    raise 'No OpenAI API key (set OPENAI_API_KEY or create sim/.openaiapikey)' if k.nil? || k.empty?
    k
  end

  # Returns the assistant message content (a String, expected to be JSON when json:true).
  def complete(system:, user:, model: 'gpt-4o', max_tokens: 2000, temperature: 0.8, json: true)
    http = Net::HTTP.new(ENDPOINT.host, ENDPOINT.port)
    http.use_ssl = true
    http.read_timeout = 180
    req = Net::HTTP::Post.new(ENDPOINT)
    req['authorization'] = "Bearer #{key}"
    req['content-type']  = 'application/json'
    body = { model: model, max_tokens: max_tokens, temperature: temperature,
             messages: [{ role: 'system', content: system },
                        { role: 'user', content: user }] }
    body[:response_format] = { type: 'json_object' } if json
    req.body = JSON.generate(body)
    attempts = 0
    loop do
      attempts += 1
      begin
        res = http.request(req)
        if %w[429 500 502 503].include?(res.code) && attempts < 6
          sleep([2**attempts, 30].min); next
        end
        raise "OpenAI API #{res.code}: #{res.body.to_s[0, 400]}" unless res.code == '200'
        data = JSON.parse(res.body)
        return data.dig('choices', 0, 'message', 'content').to_s
      rescue Net::ReadTimeout, Net::OpenTimeout, Errno::ECONNRESET, SocketError, EOFError => e
        raise e if attempts >= 6
        sleep([2**attempts, 30].min)
      end
    end
  end
end

# Quick connectivity self-test:  ruby openai_client.rb [model]
if __FILE__ == $PROGRAM_NAME
  model = ARGV[0] || 'gpt-4o'
  out = OpenAIClient.complete(
    system: 'You return strict JSON.',
    user: 'Return {"ok":true,"model_said":"hello"} exactly.',
    model: model, max_tokens: 50)
  puts "model=#{model} -> #{out}"
end
