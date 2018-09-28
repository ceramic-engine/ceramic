Pod::Spec.new do |spec|
  spec.name             = 'CeramicIosSupport'
  spec.version          = '0.1.0'
  spec.license          = { :type => 'MIT' }
  spec.homepage         = 'https://github.com/ceramic-engine/ceramic/plugins/ios'
  spec.authors          = { 'Jeremy Faivre' => 'contact@jeremyfa.com' }
  spec.summary          = 'Ceramic Ios Support library.'
  spec.source_files     = 'CeramicIosSupport/Support/*.{h,m}'
  spec.source           = { :git => 'https://github.com/ceramic-engine/ceramic.git' }
  spec.platform         = :ios, "8.0"
  spec.requires_arc     = true
  spec.frameworks       = 'Foundation'
end