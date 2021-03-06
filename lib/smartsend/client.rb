require 'http'
require 'logger'

class Smartsend::Client
  @@logging = false

  def self.with_logs
    @@logging = true
    yield
    @@logging = false
  end

  def initialize(account=nil)
    @account = account || Smartsend.account
  end

  def post(path, params)
    log("POST #{path}")
    log(params)

    request do
      http.post(url(path), json: params)
    end
  end

  def get(path)
    log("GET #{path}")

    request do
      http.get(url(path))
    end
  end

  def get_plain(path)
    http.get(url(path))
  end

  def request
    response = yield

    log(response)
    log(response.body.to_s)

    case response.code
    when (200..299)
      Response.new(JSON.parse(response)).successful!(response.code)
    when 401
      raise Smartsend::AuthorizationError, 'Unable to authorize'
    when 404
      raise Smartsend::NotFoundError, 'Resource not found'
    else
      Response.new(JSON.parse(response)).failed!(response.code)
    end
  end

  class Response < SimpleDelegator
    attr_reader :http_code

    def successful!(http_code)
      @http_code = http_code
      @success = true
      self
    end

    def failed!(http_code)
      @http_code = http_code
      @success = false
      self
    end

    def success?
      @success
    end

    def failed?
      !@success
    end

  end

  private

  def log(value)
    Logger.new($stdout).log(value) if @@logging
  end

  BASE_URL = 'http://smartsend-prod.apigee.net/api/v1'.freeze

  def url(path)
    "#{BASE_URL}/#{path}?api_token=#{@account.api_token}"
  end

  def user_agent_string
    (["Ruby/#{Smartsend::VERSION}"] + @account.user_agents.to_a).join(' ')
  end

  def http
    raise Smartsend::MissingConfigError, 'Missing api_token' if @account.api_token.nil?

    HTTP.headers({
      accept: 'application/json',
      user_agent: user_agent_string,
      referer: @account.referer
    })
  end

end
