# frozen_string_literal: true

module MobileDetection
  def self.mobile_device?(user_agent)
    user_agent =~ /Mobile/ && !(user_agent =~ /iPad/)
  end

  # we need this as a reusable chunk that is called from the cache
  def self.resolve_mobile_view!(user_agent, params, session)
    return false unless SiteSetting.enable_mobile_theme

    session[:mobile_view] = params[:mobile_view] if params && params.has_key?(:mobile_view)
    session[:mobile_view] = nil if params && params.has_key?(:mobile_view) &&
      params[:mobile_view] == "auto"

    if session && session[:mobile_view]
      session[:mobile_view] == "1"
    else
      mobile_device?(user_agent)
    end
  end

  MODERN_MOBILE_REGEX =
    %r{
    \(.*iPhone\ OS\ 1[5-9].*\)|
    \(.*iPad.*OS\ 1[5-9].*\)|
    Chrome\/8[89]|
    Chrome\/9[0-9]|
    Chrome\/1[0-9][0-9]|
    Firefox\/8[5-9]|
    Firefox\/9[0-9]|
    Firefox\/1[0-9][0-9]
  }x

  USER_AGENT_MAX_LENGTH = 400

  def self.modern_mobile_device?(user_agent)
    user_agent[0...USER_AGENT_MAX_LENGTH].match?(MODERN_MOBILE_REGEX)
  end

  def self.device_type(user_agent)
    return :unknown if user_agent.blank?
    
    if user_agent =~ /iPhone|iPod/i
      :iphone
    elsif user_agent =~ /iPad/i
      :ipad
    elsif user_agent =~ /Android.*Mobile/i
      :android_phone
    elsif user_agent =~ /Android/i
      :android_tablet
    elsif user_agent =~ /Windows Phone/i
      :windows_phone
    elsif user_agent =~ /Mobile/i
      :mobile_other
    else
      :desktop
    end
  end

  def self.supports_modern_css?(user_agent)
    return true if user_agent.blank?
    
    device = device_type(user_agent)
    return true if [:desktop, :iphone, :ipad, :android_phone, :android_tablet].include?(device)
    
    # Check for modern browser versions
    if user_agent =~ /Chrome\/(\d+)/
      $1.to_i >= 60
    elsif user_agent =~ /Firefox\/(\d+)/
      $1.to_i >= 55
    elsif user_agent =~ /Safari\/(\d+)/
      $1.to_i >= 10
    else
      false
    end
  end
end
