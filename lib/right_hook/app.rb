require 'sinatra/base'
require 'json'

require 'right_hook/event'

module RightHook
  class App < Sinatra::Base
    post '/hook/:owner/:repo_name/:event_type' do
      owner = params[:owner]
      repo_name = params[:repo_name]
      event_type = params[:event_type]
      content = request.body.read

      halt 404, "Unknown event type" unless Event::KNOWN_TYPES.include?(event_type)
      halt 501, "Event type not implemented" unless respond_to?("on_#{event_type}")

      require_valid_signature(content, owner, repo_name, event_type)

      json = JSON.parse(content)
      case event_type
      when Event::PULL_REQUEST
        on_pull_request(owner, repo_name, json['number'], json['action'], json['pull_request'])
      when Event::ISSUE
        on_issue(owner, repo_name, json['action'], json['issue'])
      else
        halt 500, "Server bug"
      end
    end

    private
    def require_valid_signature(content, owner, repo_name, event_type)
      s = secret(owner, repo_name, event_type)
      expected_signature = OpenSSL::HMAC.hexdigest(OpenSSL::Digest::Digest.new('sha1'), s, content)

      # http://pubsubhubbub.googlecode.com/git/pubsubhubbub-core-0.4.html#authednotify
      # "If the signature does not match, subscribers MUST still return a 2xx success response to acknowledge receipt, but locally ignore the message as invalid."
      halt 202, "Signature mismatch" unless request.env['X-Hub-Signature'] == "sha1=#{expected_signature}"
    end
  end
end
