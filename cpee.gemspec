Gem::Specification.new do |s|
  s.name             = "cpee"
  s.version          = "1.3.102"
  s.platform         = Gem::Platform::RUBY
  s.license          = "LGPL-3"
  s.summary          = "Preliminary release of cloud process execution engine (cpee). If you just need workflow execution, without a rest/xmpp service exposing it, then use WEEL"

  s.description      = "Preliminary release of cloud process execution engine (cpee). If you just need workflow execution, without a rest/xmpp service exposing it, then use WEEL"

  s.files            = Dir['{example/**/*,server/**/*,lib/**/*,cockpit/**/*,contrib/logo*,contrib/Screen*}'] + %w(COPYING FEATURES INSTALL Rakefile cpee.gemspec README AUTHORS)
  s.require_path     = 'lib'
  s.extra_rdoc_files = ['README']
  s.test_files       = Dir['{test/*,test/*/tc_*.rb}']

  s.required_ruby_version = '>=1.9.3'

  s.authors          = ['Juergen eTM Mangler','Ralph Vigne','Gerhard Stuermer']
  s.email            = 'juergen.mangler@gmail.com'
  s.homepage         = 'http://www.wst.univie.ac.at/workgroups/wee/'

  s.add_runtime_dependency 'riddl'
  s.add_runtime_dependency 'weel'
  s.add_runtime_dependency 'savon'
end
