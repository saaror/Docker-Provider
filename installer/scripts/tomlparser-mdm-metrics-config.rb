#!/usr/local/bin/ruby

require_relative "tomlrb"
require_relative "ConfigParseErrorLogger"

@configMapMountPath = "/etc/config/settings/mdm-metrics-configuration-settings"
@configVersion = ""
@configSchemaVersion = ""
# Setting default values which will be used in case they are not set in the configmap or if configmap doesnt exist
@percentageCpuUsageThreshold = 95.0
@percentageMemoryRssThreshold = 95.0
@percentageMemoryWorkingSetThreshold = 95.0

# Use parser to parse the configmap toml file to a ruby structure
def parseConfigMap
  begin
    # Check to see if config map is created
    if (File.file?(@configMapMountPath))
      puts "config::configmap container-azm-ms-agentconfig for MDM metric settings mounted, parsing values"
      parsedConfig = Tomlrb.load_file(@configMapMountPath, symbolize_keys: true)
      puts "config::Successfully parsed mounted config map"
      return parsedConfig
    else
      puts "config::configmap container-azm-ms-agentconfig for MDM metrics settings not mounted, using defaults"
      return nil
    end
  rescue => errorStr
    ConfigParseErrorLogger.logError("Exception while parsing config map for MDM metric settings: #{errorStr}, using defaults, please check config map for errors")
    return nil
  end
end

# Use the ruby structure created after config parsing to set the right values to be used for MDM metric configuration settings
def populateSettingValuesFromConfigMap(parsedConfig)
  if !parsedConfig.nil? && !parsedConfig[:mdm_metrics_configuration_settings].nil?
    # Get mdm metrics config settings for resource utilization
    begin
      resourceUtilization = parsedConfig[:mdm_metrics_configuration_settings][:resource_utilization]
      if !resourceUtilization.nil?
        @percentageCpuUsageThreshold = resourceUtilization[:percentage_cpu_utilization_threshold]
        @percentageMemoryRssThreshold = resourceUtilization[:percentage_memory_rss_threshold]
        @percentageMemoryWorkingSetThreshold = resourceUtilization[:percentage_memory_working_set_threshold]
        puts "config::Using config map settings for MDM metric configuration settings for resource utilization"
      end
    rescue => errorStr
      ConfigParseErrorLogger.logError("Exception while reading config map settings for MDM metric configuration settings for resource utilization - #{errorStr}, using defaults, please check config map for errors")
      @percentageCpuUsageThreshold = 95.0
      @percentageMemoryRssThreshold = 95.0
      @percentageMemoryWorkingSetThreshold = 95.0
    end
  end
end

@configSchemaVersion = ENV["AZMON_AGENT_CFG_SCHEMA_VERSION"]
puts "****************Start MDM Metrics Config Processing********************"
if !@configSchemaVersion.nil? && !@configSchemaVersion.empty? && @configSchemaVersion.strip.casecmp("v1") == 0 #note v1 is the only supported schema version, so hardcoding it
  configMapSettings = parseConfigMap
  if !configMapSettings.nil?
    populateSettingValuesFromConfigMap(configMapSettings)
  end
else
  if (File.file?(@configMapMountPath))
    ConfigParseErrorLogger.logError("config::unsupported/missing config schema version - '#{@configSchemaVersion}' , using defaults, please use supported schema version")
  end
end

# Write the settings to file, so that they can be set as environment variables
file = File.open("config_mdm_metrics_env_var", "w")

if !file.nil?
  file.write("export AZMON_MDM_CPU_UTILIZATION_THRESHOLD=#{@percentageCpuUsageThreshold}\n")
  file.write("export AZMON_MDM_MEMORY_RSS_THRESHOLD=#{@percentageMemoryRssThreshold}\n")
  file.write("export AZMON_MDM_MEMORY_WORKING_SET_THRESHOLD=\"#{@percentageMemoryWorkingSetThreshold}\"\n")
  # Close file after writing all MDM setting environment variables
  file.close
  puts "****************End MDM Metrics Config Processing********************"
else
  puts "Exception while opening file for writing MDM metric config environment variables"
  puts "****************End MDM Metrics Config Processing********************"
end
