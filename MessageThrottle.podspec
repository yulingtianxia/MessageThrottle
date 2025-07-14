Pod::Spec.new do |s|
s.name         = "MessageThrottle"
s.version      = "1.4.3"
s.summary      = "A lightweight Objective-C message throttle and debounce library."
s.description  = <<-DESC
MessageThrottle is a lightweight, simple library for controlling frequency of forwarding Objective-C messages. You can choose to control existing methods per instance or per class. It's an implementation of function throttle/debounce developed with Objective-C runtime. 
DESC
s.homepage     = "https://github.com/yulingtianxia/MessageThrottle"

s.license = { :type => 'MIT', :file => 'LICENSE' }
s.author       = { "YangXiaoyu" => "yulingtianxia@gmail.com" }
s.social_media_url = 'https://twitter.com/yulingtianxia'
s.source       = { :git => "https://github.com/yulingtianxia/MessageThrottle.git", :tag => s.version.to_s }


s.subspec 'MTCore' do |ss|
  ss.source_files = 'MessageThrottle/MTCore/*.{h,m}'
  ss.frameworks = 'MTCore'
  ss.ios.deployment_target = "6.0"
  ss.osx.deployment_target = "10.8"
  ss.watchos.deployment_target = "2.0"
  ss.tvos.deployment_target = "9.0"
  ss.requires_arc = true
end

s.subspec 'MTArchive' do |ss|
  ss.source_files = 'MessageThrottle/MTArchive/*.{h,m}'
  ss.frameworks = 'MTArchive'
  ss.dependency 'MTCore'
  ss.ios.deployment_target = "6.0"
  ss.osx.deployment_target = "10.8"
  ss.watchos.deployment_target = "2.0"
  ss.tvos.deployment_target = "9.0"
  ss.requires_arc = true
end

s.default_subspec = 'MTCore', 'MTArchive'
s.public_header_files = "MessageThrottle/MTCore/MessageThrottle.h"
s.frameworks = 'Foundation'

end
