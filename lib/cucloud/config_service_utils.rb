module Cucloud
  # ConfigServiceUtils - Utilities for Config Service
  class ConfigServiceUtils
    # http://docs.aws.amazon.com/general/latest/gr/rande.html#awsconfig_region
    CONFIG_REGIONS = ['us-east-1',
                      'us-west-2',
                      'eu-west-1',
                      'eu-central-1',
                      'ap-northeast-1'].freeze

    # Declare error classes
    class UnsupportedRegionError < StandardError
    end

    # Config service is limited to a subset of regions - get currently supported list
    # @return [Array<String>] Array of region names
    def self.get_available_regions
      CONFIG_REGIONS
    end

    # Constructor for ConfigServiceUtilsclass
    # @param [Aws::ConfigService::Client] AWS ConfigService SDK Client
    def initialize(cs_client = Aws::ConfigService::Client.new)
      unless Cucloud::ConfigServiceUtils.get_available_regions.include? Cucloud.region
        raise Cucloud::ConfigServiceUtils::UnsupportedRegionError,
              "Region #{Cucloud.region} not yet supported by config service"
      end

      @cs = cs_client
      @region = Cucloud.region
    end

    # Get array of configuration rules for given region
    # @return [Array<Aws::ConfigService::Types::ConfigRule>] Array of config rules
    def get_config_rules
      # https://docs.aws.amazon.com/sdkforruby/api/Aws/ConfigService/Client.html#describe_config_rules-instance_method
      @cs.describe_config_rules.config_rules
    end

    # Get specific config rule by name
    # @param [String] Config rule name
    # @return [Aws::ConfigService::Types::ConfigRule] Rule
    def get_config_rule_by_name(rule_name)
      # https://docs.aws.amazon.com/sdkforruby/api/Aws/ConfigService/Client.html#describe_config_rules-instance_method
      @cs.describe_config_rules(
        config_rule_names: [rule_name]
      ).config_rules.first
    end

    # Get evaluation status of rule by name
    # @param [String] Rule name
    # @return [Types::ConfigRuleEvaluationStatus] Evaluation status of rule
    def get_rule_evaluation_status_by_name(rule_name)
      # https://docs.aws.amazon.com/sdkforruby/api/Aws/ConfigService/Client.html#describe_config_rule_evaluation_status-instance_method
      @cs.describe_config_rule_evaluation_status(
        config_rule_names: [rule_name]
      ).config_rules_evaluation_status.first
    end

    # Get compliance details for a given rule by name
    # @param [String] Rule name
    # @return [Types::EvaluationResult]
    # @TODO verify that first return is always what we want?  i.e, always ordered decending by date?
    def get_rule_compliance_by_name(rule_name)
      # https://docs.aws.amazon.com/sdkforruby/api/Aws/ConfigService/Client.html#describe_config_rule_evaluation_status-instance_method
      @cs.get_compliance_details_by_config_rule(
        config_rule_name: rule_name
      ).evaluation_results.first
    end

    # Are all recorders active and logging data in this region
    # @return [Boolean]
    def recorder_active?
      @cs.describe_configuration_recorder_status({})
         .configuration_recorders_status.find { |x| !x.recording || x.last_status != 'SUCCESS' }.nil?
    end

    # Is this rule active?
    # @param [Aws::ConfigService::Types::ConfigRule] Rule
    # @return [Boolean]
    def rule_active?(rule)
      rule.config_rule_state == 'ACTIVE'
    end

    # Is this rule currently passing?
    # @param [Aws::ConfigService::Types::ConfigRule] Rule
    # @return [Boolean]
    def rule_compliant?(rule)
      get_rule_compliance_by_name(rule.config_rule_name).compliance_type == 'COMPLIANT'
    end

    # Get hours since last config check invocation
    # @param [Aws::ConfigService::Types::ConfigRule] Rule
    # @return [Integer] Hours
    def hours_since_last_run(rule)
      last_run_time = get_rule_evaluation_status_by_name(rule.config_rule_name).last_successful_invocation_time
      return nil if last_run_time.nil?

      ((Time.now - last_run_time) / 60 / 60).to_i
    end
  end
end
