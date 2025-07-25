# frozen_string_literal: true

require "rails_helper"
require "api_content_negotiation"

describe ApiContentNegotiation do
  let(:mock_request) do
    double("request", 
      headers: {
        "Accept" => "application/json, text/plain",
        "User-Agent" => "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
        "Accept-Encoding" => "gzip, deflate"
      },
      params: {}
    )
  end

  describe ".negotiate_content_type" do
    context "with mobile client" do
      let(:mobile_request) do
        double("request",
          headers: {
            "Accept" => "application/json, application/xml;q=0.8",
            "User-Agent" => "Mozilla/5.0 (iPhone; CPU iPhone OS 14_6 like Mac OS X)"
          }
        )
      end

      it "returns mobile-optimized content type" do
        result = described_class.negotiate_content_type(mobile_request)
        expect(result).to eq("application/json")
      end
    end

    context "with API client" do
      let(:api_request) do
        double("request",
          headers: {
            "Accept" => "application/vnd.api+json, application/json;q=0.8",
            "User-Agent" => "curl/7.68.0"
          }
        )
      end

      it "returns requested API content type" do
        result = described_class.negotiate_content_type(api_request)
        expect(result).to eq("application/vnd.api+json")
      end
    end

    context "with blank Accept header" do
      let(:blank_request) do
        double("request", headers: { "Accept" => "", "User-Agent" => "test" })
      end

      it "returns default content type" do
        result = described_class.negotiate_content_type(blank_request)
        expect(result).to eq("application/json")
      end
    end
  end

  describe ".analyze_api_client_capabilities" do
    it "analyzes client capabilities correctly" do
      capabilities = described_class.analyze_api_client_capabilities(mock_request)
      
      expect(capabilities[:accept_header]).to eq("application/json, text/plain")
      expect(capabilities[:supports_compression]).to be true
      expect(capabilities[:preferred_format]).to eq("application/json")
      expect(capabilities[:client_type]).to eq(:browser)
    end

    context "with mobile client" do
      let(:mobile_request) do
        double("request",
          headers: {
            "Accept" => "application/json",
            "User-Agent" => "Mobile Safari",
            "Accept-Encoding" => "gzip"
          },
          params: {}
        )
      end

      it "identifies mobile client correctly" do
        capabilities = described_class.analyze_api_client_capabilities(mobile_request)
        expect(capabilities[:client_type]).to eq(:mobile)
        expect(capabilities[:bandwidth_preference]).to eq(:minimal)
      end
    end

    context "with API client" do
      let(:api_client_request) do
        double("request",
          headers: {
            "Accept" => "application/json",
            "User-Agent" => "curl/7.68.0",
            "Accept-Encoding" => "gzip, br"
          },
          params: {}
        )
      end

      it "identifies API client correctly" do
        capabilities = described_class.analyze_api_client_capabilities(api_client_request)
        expect(capabilities[:client_type]).to eq(:api_client)
        expect(capabilities[:bandwidth_preference]).to eq(:complete)
      end
    end
  end

  describe ".optimize_response_for_client" do
    let(:sample_data) do
      {
        "id" => 1,
        "title" => "Test Post",
        "content" => "Test content",
        "debug_info" => "Debug data",
        "admin_fields" => "Admin only"
      }
    end

    context "for mobile client" do
      let(:mobile_capabilities) do
        {
          preferred_format: "application/json",
          client_type: :mobile,
          bandwidth_preference: :minimal
        }
      end

      it "optimizes data for mobile" do
        result = described_class.optimize_response_for_client(sample_data, mobile_capabilities)
        parsed_result = JSON.parse(result)
        
        expect(parsed_result).not_to have_key("debug_info")
        expect(parsed_result).not_to have_key("admin_fields")
        expect(parsed_result).to have_key("id")
        expect(parsed_result).to have_key("title")
      end
    end

    context "for API client" do
      let(:api_capabilities) do
        {
          preferred_format: "application/json",
          client_type: :api_client,
          bandwidth_preference: :complete
        }
      end

      it "adds API metadata" do
        result = described_class.optimize_response_for_client(sample_data, api_capabilities)
        parsed_result = JSON.parse(result)
        
        expect(parsed_result).to have_key("_api_metadata")
        expect(parsed_result["_api_metadata"]).to have_key("version")
        expect(parsed_result["_api_metadata"]).to have_key("timestamp")
      end
    end

    context "for webhook client" do
      let(:webhook_capabilities) do
        {
          preferred_format: "application/json",
          client_type: :webhook,
          bandwidth_preference: :efficient
        }
      end

      it "returns essential data only" do
        result = described_class.optimize_response_for_client(sample_data, webhook_capabilities)
        parsed_result = JSON.parse(result)
        
        # Should only include essential keys for webhooks
        expect(parsed_result.keys.length).to be <= 5
        expect(parsed_result).to have_key("id")
      end
    end
  end

  describe "content type parsing" do
    it "parses complex Accept headers correctly" do
      complex_accept = "application/json;q=0.9,application/xml;q=0.8,text/plain;q=0.7,*/*;q=0.1"
      preferences = described_class.send(:parse_accept_header, complex_accept)
      
      expect(preferences.first[:type]).to eq("application/json")
      expect(preferences.first[:quality]).to eq(0.9)
      
      expect(preferences.last[:type]).to eq("*/*")
      expect(preferences.last[:quality]).to eq(0.1)
    end

    it "handles Accept headers with parameters" do
      accept_with_params = "application/json;charset=utf-8;q=0.9,text/html"
      preferences = described_class.send(:parse_accept_header, accept_with_params)
      
      json_pref = preferences.find { |p| p[:type] == "application/json" }
      expect(json_pref[:parameters]).to have_key("charset")
      expect(json_pref[:parameters]["charset"]).to eq("utf-8")
    end
  end

  describe "client type detection" do
    it "detects webhook clients" do
      webhook_request = double("request", 
        headers: { "User-Agent" => "GitHub-Hookshot/webhook" }
      )
      
      client_type = described_class.send(:determine_client_type, webhook_request)
      expect(client_type).to eq(:webhook)
    end

    it "detects API clients" do
      api_request = double("request",
        headers: { "User-Agent" => "Postman Runtime/7.28.4" }
      )
      
      client_type = described_class.send(:determine_client_type, api_request)
      expect(client_type).to eq(:api_client)
    end
  end
end