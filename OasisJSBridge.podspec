
Pod::Spec.new do |s|
  s.name             = 'OasisJSBridge'
  s.version          = '0.3.1'
  s.summary          = 'JavaScript bridge for iOS using JavascriptCore.'
  s.description      = "JSBridge, javascript bridge for iOS using JavascriptCore."
  s.homepage         = 'https://gitlab.p7s1.io/oasis-player/native-jsbridge-ios'
  s.license          = { :type => 'Apache License', :file => 'LICENSE' }
  s.author           = { 'cmps' => 'cmps@prosiebensat1digital.de' }
  s.source           = { :git => 'git@gitlab.p7s1.io:oasis-player/native-jsbridge-ios.git', :tag => s.version.to_s }

  s.ios.deployment_target = '9.0'
  s.tvos.deployment_target = '9.0'
  s.swift_version = '5.0'
  s.static_framework = false
  s.source_files = 'JSBridge/Classes/**/*'
  s.resources = 'JSBridge/Assets/*.js'
  
  s.xcconfig = {
    "DEFINES_MODULE" => "YES"
  }

  # s.public_header_files = 'Pod/Classes/**/*.h'
  # s.dependency 'AFNetworking', '~> 2.3'
  s.frameworks = 'UIKit', 'JavaScriptCore'
end

