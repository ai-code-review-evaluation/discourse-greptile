require "spec_helper"
require_dependency "content_negotiation"

describe ContentNegotiation do

  describe ".best_content_type" do
    it "returns html for standard browser accept header" do
      env = { "HTTP_ACCEPT" => "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8" }
      result = ContentNegotiation.best_content_type(env)
      result.should == "text/html"
    end

    it "returns json for api requests" do
      env = { "HTTP_ACCEPT" => "application/json,*/*;q=0.8" }
      result = ContentNegotiation.best_content_type(env)
      result.should == "application/json"
    end

    it "respects quality scores" do
      env = { "HTTP_ACCEPT" => "application/json;q=0.5,text/html;q=0.9" }
      result = ContentNegotiation.best_content_type(env)
      result.should == "text/html"
    end

    it "handles missing accept header" do
      env = {}
      result = ContentNegotiation.best_content_type(env)
      result.should == "text/html"
    end
  end

  describe ".supports_compression?" do
    it "detects gzip support" do
      env = { "HTTP_ACCEPT_ENCODING" => "gzip, deflate" }
      result = ContentNegotiation.supports_compression?(env)
      result.should be_true
    end

    it "handles missing encoding header" do
      env = {}
      result = ContentNegotiation.supports_compression?(env)
      result.should be_false
    end
  end

end