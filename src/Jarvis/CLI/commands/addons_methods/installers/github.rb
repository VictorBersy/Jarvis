require 'Jarvis/API/profile'
require 'open-uri'
require 'octokit'
require 'open3'
require 'yaml'
module Jarvis
  module CLI
    module Installers
      class Github
        def initialize(addon)
          @octokit_client = octokit_client
          @repo = addon[:name]
          @version = addon[:version]
          @options = addon[:options]
          retrieve_data
          if release_matched?
            install(@version_to_install)
          else
            warn_version_doesnt_exist
          end
        end

        def octokit_client
          if defined? Jarvis::API::Profile.user.profile['tokens']['github']
            token = Jarvis::API::Profile.user.profile['tokens']['github']
            Octokit::Client.new(access_token: token)
          else
            Octokit::Client.new
          end
        end

        def retrieve_data
          Jarvis::Utility::Logger.info("Retrieving data from github for '#{@repo}'...")
          @specs = specs
          @releases = releases
        end

        def specs
          specs_url = "https://raw.githubusercontent.com/#{@repo}/master/specs.yml"
          begin
            specs = YAML.load open(specs_url).read
          rescue OpenURI::HTTPError => e
            Utility::Logger.error("#{e.io.status.shift} #{e.io.status.shift} : '#{specs_url}' wasn't found")
          end
          Jarvis::Utility::Logger.info("'#{@repo}' found!", color: :green)
          Jarvis::Utility::Logger.info("[#{specs['specs']['type'].upcase}] '#{specs['specs']['name']}', created by '#{specs['author']['name']}'.", color: :green)
          specs
        end

        def releases
          @octokit_client.releases(@repo)
        end

        def normalize_version(version)
          version.gsub(/^\D+/, '')
        end

        def release_matched?
          @found_versions = []
          @releases.each do |release|
            release_version = release[:tag_name]
            @found_versions.push normalize_version(release_version)
            if Gem::Dependency.new(@repo, @version).match?(@repo, normalize_version(release_version))
              @version_to_install = release_version
              return true
            end
          end
          false
        end

        def warn_version_doesnt_exist
          Jarvis::Utility::Logger.warning("This release version (#{normalize_version(@version)}) doesn't exist in #{@repo}.")
          Jarvis::Utility::Logger.warning("I only found those versions : #{@found_versions}")
        end

        def install(version)
          Jarvis::Utility::Logger.info("Installing '#{@repo} #{version}'", color: :green)
          author = @specs['author']['name'].delete(' ')
          name = @specs['specs']['name']
          github_link = "https://github.com/#{@repo}"
          install_path = File.join(JARVIS[:root], 'addons', "#{@specs['specs']['type']}s", "#{author}-#{name}-#{version}")
          git %(clone --branch #{version} #{github_link} #{install_path})
        end

        private

        def git(command)
          Open3.popen3("git #{command}") do |_i, _o, e, t|
            if t.value == 0
              Stdio.done("'#{@repo}' has been successfully installed!")
            else
              Stdio.not_done("'#{@repo}' hasn't been installed!")
              Jarvis::Utility::Logger.warning(e.read.strip)
            end
          end
        end
      end
    end
  end
end
