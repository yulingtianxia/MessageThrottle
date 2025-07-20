Pod::Spec.new do |s|
s.name         = "MessageThrottle"
s.version      = "1.5.0"
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
  ss.public_header_files = "MessageThrottle/MTCore/MessageThrottle.h"
end

s.subspec 'MTArchive' do |ss|
  ss.source_files = 'MessageThrottle/MTArchive/*.{h,m}'
  ss.dependency 'MessageThrottle/MTCore'
  ss.public_header_files = "MessageThrottle/MTArchive/MTEngine+MTArchive.h"
end

s.ios.deployment_target = "12.0"
s.osx.deployment_target = "10.13"
s.watchos.deployment_target = "4.0"
s.tvos.deployment_target = "12.0"
s.requires_arc = true

s.default_subspec = ['MTCore', 'MTArchive']
s.frameworks = 'Foundation'

end