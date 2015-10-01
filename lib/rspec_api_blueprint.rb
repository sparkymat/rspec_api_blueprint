require "rspec_api_blueprint/version"
require "rspec_api_blueprint/string_extensions"


RSpec.configure do |config|
  config.before(:suite) do
    if defined? Rails
      api_docs_folder_path = File.join(Rails.root, '/api_docs/')
    else
      api_docs_folder_path = File.join(File.expand_path('.'), '/api_docs/')
    end

    Dir.mkdir(api_docs_folder_path) unless Dir.exists?(api_docs_folder_path)

    Dir.glob(File.join(api_docs_folder_path, '*')).each do |f|
      File.delete(f)
    end
  end

  config.after(:suite) do
    api_docs_folder_path = File.join(File.expand_path('.'), '/api_docs/')
    file = File.join(File.expand_path('.'), "/api_docs/api.md")

    fp = File.open(file, 'w+')

    fp.puts "FORMAT: 1A"
    fp.puts "HOST: http://base_api"
    fp.puts ""

    fp.puts "# #{File.basename(Dir.pwd).gsub(/[^a-zA-Z_]/,'_').camelize}"
    fp.puts ""

    Dir.glob(File.join(api_docs_folder_path, '*.txt')).each do |f|
      section_name = File.basename(f, ".txt")
      fp.puts "# Group #{section_name.camelize}"
      fp.puts ""

      IO.readlines(f).each do |l|
        fp.print(l)
      end

      fp.puts ""
    end

    fp.close
  end

  config.after(:example, type: :request) do |example|
    response ||= @response # This has to be set in every test 
    request ||= (@response.nil? ? nil? : @response.request)

    if response
      example_group = example.metadata[:example_group]
      example_groups = []

      while example_group
        example_groups << example_group
        example_group = example_group[:example_group]
      end

      action = example_groups[-2][:description_args].first if example_groups[-2]
      example_groups[-1][:description_args].first.match(/(\w+)\sRequests/)
      file_name = $1.underscore

      if defined? Rails
        file = File.join(Rails.root, "/api_docs/#{file_name}.txt")
      else
        file = File.join(File.expand_path('.'), "/api_docs/#{file_name}.txt")
      end

      File.open(file, 'a') do |f|
        # Resource & Action
        f.write "## #{action}\n\n"

        # Request
        request_body = request.raw_body
        authorization_header = request.options[:headers].nil? ? nil : request.options[:headers]['Authorization']
        content_type = request.options[:headers].nil? ? nil : request.options[:headers]['Content-Type']

        semiparsed_request_hash = request_body.split("&").map{|e| e.split("=")}
        parsed_body = nil

        if semiparsed_request_hash.is_a?(Array) && semiparsed_request_hash.map(&:class).uniq == [Array] && semiparsed_request_hash.map(&:count).uniq == [2]
          parsed_body = semiparsed_request_hash.to_h
          content_type = "application/x-www-form-urlencoded"
        end

        if !request_body.nil? || !authorization_header.nil?
          f.write "+ Request (#{content_type})\n\n"

          # Request Headers
          if !authorization_header.nil?
            f.write "+ Headers\n\n".indent(4)
            f.write "Authorization: #{authorization_header}\n\n".indent(12)
          end

          # Request Body
          if !request_body.nil? && content_type == 'application/json'
            f.write "+ Body\n\n".indent(4) if authorization_header
            f.write "#{JSON.pretty_generate(JSON.parse(request_body))}\n\n".indent(authorization_header ? 12 : 8)
          end

          if !parsed_body.nil? && content_type == 'application/x-www-form-urlencoded'
            f.write "+ Parameters\n".indent(4)
            parsed_body.each_pair do |k,v|
              f.write "+ #{k}: \"#{v}\" (#{v.class})\n".indent(8)
            end
            f.write "\n"
          end
        end

        # Response
        f.write "+ Response #{response.code} (#{response.content_type})\n\n"

        if !response.body.nil? && response.content_type == 'application/json'
          f.write "#{JSON.pretty_generate(JSON.parse(response.body))}\n\n".indent(8)
        end
      end unless response.code == 401 || response.code == 403 || response.code == 301
    end
  end
end
