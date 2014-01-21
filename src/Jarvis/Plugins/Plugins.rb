module Jarvis
  class Plugins
    def initialize
      @registered_plugins   = {}
      @plugins_directories  = Array.new
    end

    def scan_directories
      Dir['../plugins/*/'].each do |directory|
        @plugins_directories.push(directory)
      end
    end

    def load_plugins
      @plugins_directories.each do |directory|
        yaml_file = File.join(directory, "plugin.yml")
        if File.exists?(yaml_file)
          plugin_specs_yaml = YAML.load_file(directory + 'plugin.yml')
          hash_md5_specs    = Digest::MD5.hexdigest(plugin_specs_yaml.to_s)
          @registered_plugins[hash_md5_specs] = plugin_specs_yaml
          Viewer::plugin_init(plugin_specs_yaml)
        end
      end
      Viewer::plugin_count(@registered_plugins.length)
    end
  end
end
