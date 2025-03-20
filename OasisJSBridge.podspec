Pod::Spec.new do |s|
  s.name             = 'OasisJSBridge'
  s.version          = '0.7.4'
  s.summary          = 'JavaScript bridge for iOS using JavascriptCore.'
  s.description      = "JSBridge, javascript bridge for iOS using JavascriptCore."
  s.homepage         = 'https://gitlab.p7s1.io/oasis-player/native-jsbridge-ios'
  s.license          = { :type => 'Apache License', :file => 'LICENSE' }
  s.author           = { 'cmps' => 'cmps@prosiebensat1digital.de' }
  s.source           = { :git => 'https://github.com/p7s1digital/oasis-jsbridge-ios.git', :tag => s.version.to_s }

  s.ios.deployment_target = '12.0'
  s.tvos.deployment_target = '12.0'
  s.swift_version = '5.0'
  s.static_framework = false
  s.source_files = 'JSBridge/Classes/**/*'
  s.resource_bundles = {
    'OasisJSBridge' => [
        'JSBridge/Classes/Resources/PrivacyInfo.xcprivacy'
    ]
  }

  s.test_spec 'Tests' do |s|
    s.source_files = 'JSBridge/Tests/**/*.swift'
    s.resources = 'JSBridge/Tests/Resources/*.js'
  end

  s.xcconfig = {
    "DEFINES_MODULE" => "YES"
  }

  s.frameworks = 'UIKit', 'JavaScriptCore'
end
