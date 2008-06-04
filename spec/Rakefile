# Load from the plugin if it is installed
$LOAD_PATH << File.join(File.dirname(__FILE__), '..', 'rspec', 'lib') 
require 'rake'
require 'rake/rdoctask'
require 'spec'
require 'spec/rake/spectask'

#desc 'Run spec tests.'
#task :default => :spec

desc 'Generate documentation for the XML RPC plugin.'
Rake::RDocTask.new(:rdoc) do |rdoc|
  rdoc.rdoc_dir = 'rdoc'
  rdoc.title    = 'XML Remote Procedure Call Application Programming Interface'
  rdoc.options << '--line-numbers' << '--inline-source'
  rdoc.rdoc_files.include('README')
  rdoc.rdoc_files.include('lib/**/*.rb')
end

namespace :spec do

  desc 'Test the specifications of the XML RPC plugin.'
  Spec::Rake::SpecTask.new(:spec) do |spec|
    #spec.spec_opts = ['--options', 'spec/spec.opts']
    #spec.spec_files = FileList['spec/**/*_spec.rb']
  end

  desc 'Document the specifications of the XML RPC plugin.'
  Spec::Rake::SpecTask.new(:doc) do |spec|
    spec.spec_opts = ["--format", "specdoc", "--dry-run"]
    #spec.spec_files = FileList['spec/**/*_spec.rb']
  end

  desc 'Review coverage for the specifications of the XML RPC plugin.'
  Spec::Rake::SpecTask.new(:rcov) do |spec|
    #spec.spec_files = FileList['spec/**/*_spec.rb']
    spec.rcov = true
    spec.rcov_opts = lambda do
      IO.readlines("spec/rcov.opts").map {|l| l.chomp.split " "}.flatten
    end
  end

end

