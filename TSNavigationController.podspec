Pod::Spec.new do |s|

  s.name         = "TSNavigationController"
  s.version      = "1.0.2"
  s.summary      = "spring animated pop on panGesture."
  s.homepage     = "https://github.com/TragedyStar/TSNavigationController"
  s.license      = "MIT"
  s.author       = { "TragedyStar" => "78370@qq.com" }

  s.platform     = :ios, "7.0"

  s.source       = { :git => "https://github.com/TragedyStar/TSNavigationController.git", :commit => "d9e3e9414c3cf080c46aa931c8a80d92af272da2" }

  s.source_files  = "TSNavigationController/*.{h,m}"

  s.requires_arc = true

end
