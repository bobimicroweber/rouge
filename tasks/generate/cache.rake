def lexer_cache_source(lexer)
  const_name = lexer.name.split('::').last.to_sym
  root = Pathname.new(Rouge::ROOT)
  demo_file = lexer.demo_file.relative_path_from(root).to_s

  # no need to pre-cache the default
  if demo_file == "lib/rouge/demos/#{lexer.tag}"
    demo_file = nil
  end

  yield "  Lexer.cache #{const_name.inspect}, #{lexer.tag.inspect} do"
  yield "    @title = #{lexer.title.inspect}"
  yield "    @desc = #{lexer.desc.inspect}"
  yield "    @option_docs = #{lexer.option_docs.to_hash.inspect}" if lexer.option_docs.any?
  yield "    @demo_file = Pathname.new(#{demo_file.inspect})" if demo_file
  yield "    @aliases = #{lexer.aliases.inspect}" if lexer.aliases.any?
  yield "    @filenames = #{lexer.filenames.inspect}" if lexer.filenames.any?
  yield "    @mimetypes = #{lexer.mimetypes.inspect}" if lexer.mimetypes.any?
  depends = lexer.ancestors.find { |p| p != lexer && p <= Rouge::Lexer }
  if depends && depends.tag
    yield "    @depends = #{depends.tag.inspect}"
  end

  if lexer.detectable?
    yield lexer.method(:detect?).source
    yield "    @detectable = true"
  else
    yield "    @detectable = false"
  end

  yield "  end"
end

namespace :generate do
  cache_file = './lib/rouge/langspec_cache.rb'
  lexer_files = Dir.glob('lib/rouge/lexers/*.rb')

  desc "Update the language cache file"
  task :cache do
    sh "echo '# noop' > #{cache_file}"
    require 'rouge'
    require 'method_source'

    Rouge::Lexers.singleton_class.send(:define_method, :preload) do |tag|
      load_helper(tag)
      Rouge::Lexer.find(tag)
    end

    File.open(cache_file, 'w') do |out|
      out.puts "# -*- coding: utf-8 -*- #"
      out.puts "# frozen_string_literal: true"
      out.puts "# automatically generated by running `rake generate:cache`"
      out.puts
      out.puts "module Rouge"

      error = lambda do |tag|
        raise "the lexer in #{tag}.rb does not seem to have the tag #{tag.inspect}."
      end

      Dir.glob('lib/rouge/lexers/*.rb').sort.each do |source_file|
        File.basename(source_file) =~ /^(.+?)[.]rb$/ or raise 'oh no'
        tag = $1

        lexer_cache_source(Rouge::Lexers.preload(tag) || error[tag]) do |line|
          out.puts line
        end
        out.puts
      end
      out.puts "end"
    end
  end
end
