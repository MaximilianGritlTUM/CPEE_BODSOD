Gem::Specification.new do |s|
  s.name             = "cpee"
  s.version          = "2.0"
  s.platform         = Gem::Platform::RUBY
  s.license          = "LGPL-3.0"
  s.summary          = "Preliminary release of cloud process execution engine (cpee.org). If you just need workflow execution, without a rest service exposing it, then use WEEL."

  s.description      = "see http://cpee.org"

  s.files            = Dir['{example/**/*,server/**/*,tools/**/*,lib/**/*,cockpit/**/*,cockpit/themes/*/*/*,contrib/logo*,contrib/Screen*}'] - Dir['{server/instances/**/*,cockpit/js_libs/**/*}'] + %w(COPYING FEATURES.md INSTALL.md Rakefile cpee.gemspec README.md AUTHORS)
  s.require_path     = 'lib'
  s.extra_rdoc_files = ['README.md']
  s.bindir           = 'tools'
  s.executables      = ['cpee']
  s.test_files       = Dir['{test/*,test/*/tc_*.rb}']

  s.required_ruby_version = '>=2.4.0'

  s.authors          = ['Juergen eTM Mangler','Ralph Vigne','Gerhard Stuermer']

  s.email            = 'juergen.mangler@gmail.com'
  s.homepage         = 'http://cpee.org/'

  s.add_runtime_dependency 'riddl', '~> 0.99'
  s.add_runtime_dependency 'weel', '~> 1.99', '>= 1.99.90'
  s.add_runtime_dependency 'highline', '~> 2.0'
  s.add_runtime_dependency 'json', '~>2.1'
  s.add_runtime_dependency 'redis', '~> 4.1'
  s.add_runtime_dependency 'rubyzip', '~>1.2'
end
