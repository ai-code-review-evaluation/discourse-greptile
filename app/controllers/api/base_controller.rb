# frozen_string_literal: true

require "api_content_negotiation"

class Api::BaseController < ApplicationController
  # Enhanced API base controller with advanced content negotiation
  
  before_action :set_api_content_preferences
  before_action :analyze_api_client_capabilities
  before_action :validate_api_version
  
  protected

  def set_api_content_preferences
    # Enhanced API content preference detection
    @api_capabilities = ApiContentNegotiation.analyze_api_client_capabilities(request)
    @preferred_content_type = @api_capabilities[:preferred_format]
    @client_type = @api_capabilities[:client_type]
    
    # Set response content type based on negotiation
    response.content_type = @preferred_content_type
  end

  def analyze_api_client_capabilities
    # Detailed client capability analysis for optimization
    @client_analysis = {
      supports_compression: @api_capabilities[:supports_compression],
      bandwidth_preference: @api_capabilities[:bandwidth_preference],
      api_version: @api_capabilities[:api_version_preference],
      pagination_support: @api_capabilities[:supports_pagination],
      device_type: determine_device_type,
      browser_family: extract_browser_family
    }
  end

  def validate_api_version
    # API version validation and compatibility handling
    requested_version = @api_capabilities[:api_version_preference]
    
    if requested_version.present?
      unless supported_api_version?(requested_version)
        render_api_error("Unsupported API version: #{requested_version}", 400)
        return
      end
    end
    
    @api_version = requested_version || default_api_version
  end

  def render_optimized_json(data, options = {})
    # Render JSON optimized for client capabilities
    optimized_data = ApiContentNegotiation.optimize_response_for_client(data, @api_capabilities)
    
    # Add API metadata based on client type
    if @client_type == :api_client
      optimized_data = add_api_metadata(optimized_data)
    end
    
    # Apply compression if supported
    if @api_capabilities[:supports_compression] && optimized_data.to_json.bytesize > 1024
      response.headers["Content-Encoding"] = "gzip"
    end
    
    render json: optimized_data, **options
  end

  def render_api_error(message, status = 400)
    error_data = {
      error: message,
      status: status,
      timestamp: Time.current.iso8601,
      api_version: @api_version
    }
    
    # Optimize error response for client
    error_data = ApiContentNegotiation.optimize_response_for_client(error_data, @api_capabilities)
    
    render json: error_data, status: status
  end

  private

  def determine_device_type
    user_agent = request.headers["User-Agent"] || ""
    
    return :unknown if user_agent.blank?
    
    case user_agent
    when /iPhone|iPod/i then :iphone
    when /iPad/i then :ipad
    when /Android.*Mobile/i then :android_phone
    when /Android/i then :android_tablet
    when /Windows Phone/i then :windows_phone
    when /Mobile/i then :mobile_other
    else :desktop
    end
  end

  def extract_browser_family
    user_agent = request.headers["User-Agent"] || ""
    
    return :unknown if user_agent.blank?
    
    case user_agent
    when /Chrome/i then :chrome
    when /Firefox/i then :firefox
    when /Safari/i then :safari
    when /Edge/i then :edge
    when /Opera/i then :opera
    when /curl/i then :curl
    when /Postman/i then :postman
    else :other
    end
  end

  def supported_api_version?(version)
    # Define supported API versions
    supported_versions = %w[v1 v2 1.0 2.0]
    supported_versions.include?(version)
  end

  def default_api_version
    "v1"
  end

  def add_api_metadata(data)
    # Add comprehensive API metadata for API clients
    metadata = {
      api_version: @api_version,
      timestamp: Time.current.iso8601,
      response_time: calculate_response_time,
      content_type: @preferred_content_type,
      compression: @api_capabilities[:supports_compression],
      client_type: @client_type,
      pagination: pagination_metadata
    }
    
    if data.is_a?(Hash)
      data.merge("_meta" => metadata)
    else
      { data: data, meta: metadata }
    end
  end

  def calculate_response_time
    # Calculate API response time for performance monitoring
    if @request_start_time
      ((Time.current - @request_start_time) * 1000).round(2)
    else
      nil
    end
  end

  def pagination_metadata
    # Return pagination metadata if applicable
    return nil unless @api_capabilities[:supports_pagination]
    
    {
      page: params[:page]&.to_i || 1,
      per_page: params[:per_page]&.to_i || 25,
      total_pages: nil, # Would be calculated based on actual data
      total_count: nil  # Would be calculated based on actual data
    }
  end
end