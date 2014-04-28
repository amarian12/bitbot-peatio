Gem::Specification.new do |s|
  s.name        = 'bitbot-peatio'
  s.version     = '0.0.1'
  s.summary     = "A bitbot adapter for peatio"
  s.description = "A bitbot adapter for peatio"
  s.authors     = ["Peatio Opensource"]
  s.email       = 'community@peatio.com'
  s.license     = 'MIT'
  s.files       = `git ls-files`.split("\n")
  s.homepage    = 'https://github.com/peatio/bitbot-peatio'
  s.add_dependency 'peatio_client'
  s.add_dependency 'bitbot'
end
