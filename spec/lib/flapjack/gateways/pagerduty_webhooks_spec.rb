require 'spec_helper'
require 'flapjack/gateways/pagerduty_webhooks'

describe Flapjack::Gateways::PagerdutyWebhooks, :sinatra => true, :logger => true do
  def app
    described_class
  end
  before(:all) do
    app.class_eval {
      set :raise_errors, true # Provided by Sinatra
    }
  end

  let(:redis) { double(::Redis) }
  let(:example_key) { "example" }

  before(:each) do
    expect(Flapjack::RedisPool).to receive(:new).and_return(redis)
    app.instance_variable_set('@config', {'shared_key' => example_key})
    app.instance_variable_set('@logger', @logger)
    app.start
  end

  context "invalid requests" do
    it "rejects requests with a missing key" do
      apost "/pagerduty/callback", "", {'CONTENT_TYPE' => 'application/json'}
      expect(last_response.status).to eq(401)
    end
    it "rejects requests with an invalid key" do
      apost "/pagerduty/callback?key=nottheexamplekey", "", {'CONTENT_TYPE' => 'application/json'}
      expect(last_response.status).to eq(403)
    end
    it "rejects requests with a badly-formatted body" do
      bodies = [
        {a: 'b'},
      ]
      bodies.each do |body|
        apost "/pagerduty/callback?key=#{example_key}", body, {'CONTENT_TYPE' => 'application/json'}
        expect(last_response.status).to eq(400)
      end
    end
  end

  context "valid requests" do
    pending "acknowledges and unacknowledges incidents" do
      apost "/pagerduty/callback?key=#{example_key}", "{ ... }", {'CONTENT_TYPE' => 'application/json'}
      expect(last_response.status).to eq(200)
    end
    pending "silently ignores irrelevant message types"
  end
end
