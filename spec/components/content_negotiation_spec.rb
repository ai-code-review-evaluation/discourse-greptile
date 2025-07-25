# frozen_string_literal: true

require "rails_helper"
require "content_negotiation"

describe ContentNegotiation do
  describe ".best_content_type" do
    it "returns first available type for blank accept header" do
      expect(ContentNegotiation.best_content_type("")).to eq("text/html")
    end

    it "returns first available type for nil accept header" do
      expect(ContentNegotiation.best_content_type(nil)).to eq("text/html")
    end

    it "returns matching content type" do
      accept = "application/json, text/html"
      expect(ContentNegotiation.best_content_type(accept)).to eq("application/json")
    end

    it "respects quality values" do
      accept = "text/html;q=0.8, application/json;q=0.9"
      expect(ContentNegotiation.best_content_type(accept)).to eq("application/json")
    end

    it "returns first available when no match found" do
      accept = "application/unknown, text/unknown"
      expect(ContentNegotiation.best_content_type(accept)).to eq("text/html")
    end
  end

  describe ".mobile_optimized_type" do
    it "returns WAP XHTML for mobile requests" do
      accept = "application/vnd.wap.xhtml+xml, text/html"
      expect(ContentNegotiation.mobile_optimized_type(accept)).to eq("application/vnd.wap.xhtml+xml")
    end

    it "falls back to XHTML for mobile" do
      accept = "application/xhtml+xml, application/json"
      expect(ContentNegotiation.mobile_optimized_type(accept)).to eq("application/xhtml+xml")
    end

    it "returns first mobile preference for blank header" do
      expect(ContentNegotiation.mobile_optimized_type("")).to eq("application/vnd.wap.xhtml+xml")
    end
  end

  describe "complex accept headers" do
    it "handles complex real-world accept headers" do
      # Real Chrome accept header
      accept = "text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8"
      expect(ContentNegotiation.best_content_type(accept)).to eq("text/html")
    end

    it "handles Firefox accept header" do
      accept = "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8"
      expect(ContentNegotiation.best_content_type(accept)).to eq("text/html")
    end

    it "handles API client accept header" do
      accept = "application/json, text/plain, */*"
      expect(ContentNegotiation.best_content_type(accept)).to eq("application/json")
    end
  end
end