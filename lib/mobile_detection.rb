module MobileDetection
  
  MOBILE_PATTERNS = [
    /Mobile/, /webOS/, /Nexus 7/, /Android/, /iPhone/, /iPod/, 
    /BlackBerry/, /IEMobile/, /Opera Mini/, /Windows Phone/
  ].freeze
  
  TABLET_PATTERNS = [
    /iPad/, /Tablet/, /Kindle/, /PlayBook/
  ].freeze
  
  def self.mobile_device?(user_agent)
    return false unless user_agent
    
    # Check for tablet first (tablets are not considered mobile)
    return false if tablet_device?(user_agent)
    
    MOBILE_PATTERNS.any? { |pattern| user_agent =~ pattern }
  end
  
  def self.tablet_device?(user_agent)
    return false unless user_agent
    TABLET_PATTERNS.any? { |pattern| user_agent =~ pattern }
  end

  # we need this as a reusable chunk that is called from the cache
  def self.resolve_mobile_view!(user_agent, params, session)
    return false unless SiteSetting.enable_mobile_theme

    session[:mobile_view] = params[:mobile_view] if params && params.has_key?(:mobile_view)

    if session && session[:mobile_view]
      session[:mobile_view] == '1'
    else
      mobile_device?(user_agent)
    end
  end
  
  def self.device_type(user_agent)
    return :tablet if tablet_device?(user_agent)
    return :mobile if mobile_device?(user_agent)
    :desktop
  end
end
