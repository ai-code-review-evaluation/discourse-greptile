# frozen_string_literal: true

require "rails_helper"

describe Middleware::ResponseOptimization do
  let(:app) { ->(env) { [200, { "Content-Type" => "text/html" }, ["<html><head></head><body>test</body></html>"]] } }
  let(:middleware) { described_class.new(app) }

  describe "#call" do
    context "with modern browser" do
      let(:env) do
        {
          "HTTP_USER_AGENT" => "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36",
          "HTTP_ACCEPT" => "text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8",
          "HTTP_ACCEPT_ENCODING" => "gzip, deflate, br"
        }
      end

      it "optimizes response for modern browsers" do
        status, headers, response = middleware.call(env)
        
        expect(status).to eq(200)
        expect(headers["X-Modern-Browser"]).to eq("true")
        expect(response.join).to include("modern-bundle.js")
      end
    end

    context "with mobile device" do
      let(:env) do
        {
          "HTTP_USER_AGENT" => "Mozilla/5.0 (iPhone; CPU iPhone OS 14_6 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/14.1.1 Mobile/15E148 Safari/604.1",
          "HTTP_ACCEPT" => "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
          "HTTP_ACCEPT_ENCODING" => "gzip, deflate"
        }
      end

      it "skips optimization for mobile devices" do
        status, headers, response = middleware.call(env)
        
        expect(status).to eq(200)
        expect(headers["X-Modern-Browser"]).to be_nil
        expect(response.join).not_to include("modern-bundle.js")
      end
    end

    context "with WebP support" do
      let(:env) do
        {
          "HTTP_USER_AGENT" => "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
          "HTTP_ACCEPT" => "text/html,application/xhtml+xml,image/webp,*/*;q=0.8",
          "HTTP_ACCEPT_ENCODING" => "gzip, deflate"
        }
      end

      let(:app_with_images) do
        ->(env) { [200, { "Content-Type" => "text/html" }, ['<html><img src="/test.jpg"><img src="/logo.png"></html>']] }
      end

      let(:middleware_with_images) { described_class.new(app_with_images) }

      it "replaces image formats with WebP" do
        status, headers, response = middleware_with_images.call(env)
        
        expect(response.join).to include('src="/test.jpg.webp"')
        expect(response.join).to include('src="/logo.png.webp"')
      end
    end
  end

  describe "browser capability detection" do
    it "detects ES6 support correctly" do
      chrome_env = { "HTTP_USER_AGENT" => "Chrome/60.0.3112.113" }
      context = middleware.send(:build_optimization_context, chrome_env, double(get_header: nil))
      
      expect(context[:browser_capabilities][:supports_es6]).to be true
    end

    it "detects CSS Grid support correctly" do
      firefox_env = { "HTTP_USER_AGENT" => "Firefox/57.0" }
      context = middleware.send(:build_optimization_context, firefox_env, double(get_header: nil))
      
      expect(context[:browser_capabilities][:supports_css_grid]).to be true
    end

    it "identifies modern browsers correctly" do
      modern_env = { "HTTP_USER_AGENT" => "Chrome/70.0.3538.110" }
      context = middleware.send(:build_optimization_context, modern_env, double(get_header: nil))
      
      expect(context[:browser_capabilities][:modern_browser]).to be true
    end
  end

  describe "content preference parsing" do
    it "parses complex Accept headers correctly" do
      accept = "text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8"
      preferences = middleware.send(:parse_content_preferences, accept)
      
      expect(preferences.first[:type]).to eq("text/html")
      expect(preferences.first[:quality]).to eq(1.0)
      
      xml_pref = preferences.find { |p| p[:type] == "application/xml" }
      expect(xml_pref[:quality]).to eq(0.9)
    end
  end
end