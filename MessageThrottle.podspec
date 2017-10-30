Pod::Spec.new do |s|
s.name         = "MessageThrottle"
s.version      = "1.0.0"
s.summary      = "A lightweight message throttle."
s.description  = <<-DESC
MessageThrottle is a tool helps you control Objective-C message's forwarding frequency.
DESC
s.homepage     = "https://github.com/yulingtianxia/MessageThrottle"

s.license = { :type => 'MIT', :file => 'LICENSE' }
s.author       = { "YangXiaoyu" => "yulingtianxia@gmail.com" }
s.social_media_url = 'https://twitter.com/yulingtianxia'
s.source       = { :git => "https://github.com/yulingtianxia/MessageThrottle.git", :tag => s.version.to_s }

s.platform     = :ios, '6.0'
s.requires_arc = true

s.source_files = "MessageThrottle/*.{h,m}"
s.public_header_files = "MessageThrottle/MTEngine.h"
s.frameworks = 'Foundation'

end
