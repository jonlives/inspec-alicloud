# frozen_string_literal: true

# Configuration helper for AliCloud & Inspec
# - Terraform expects a JSON variable file
# - Inspec expects a YAML attribute file
# This allows to store all transient parameters in one place.
# If any of the @config keys are exported as environment variables in uppercase, these take precedence.
require 'json'
require 'yaml'

module AliCloudInspecConfig
  
  # helper method for adding random strings
  def self.add_random_string(length = 25)
    (0...length).map { rand(65..90).chr }.join.downcase.to_s
  end

  @alicloud_region = ENV['alicloud_region'] || 'eu-west-1'

  # Config for terraform / inspec in the below hash
  @config = {
      # Generic AliCloud resource parameters
      alicloud_region: @alicloud_region,
      alicloud_vpc_name: "vpc-#{add_random_string}",
      alicloud_vpc_cidr: '10.0.1.0/24',
      alicloud_security_group_name: "sg-#{add_random_string}",
      alicloud_security_group_description: 'Test security group for inspec',
      alicloud_action_trail_ram_role_name: "atrr-#{add_random_string}",
      alicloud_action_trail_ram_role_description: 'ActionTrail ram role',
      alicloud_action_trail_ram_policy_name: "atrp-#{add_random_string}",
      alicloud_action_trail_ram_policy_description: 'ActionTrail ram policy',
      alicloud_action_trail_name: "at-#{add_random_string}",
      alicloud_action_trail_bucket_name: "atb-#{add_random_string}",
      alicloud_disk_name: "d-#{add_random_string}",
      alicloud_disk_size: '20',
      alicloud_disk_desc: "Test disk for inspec",
      alicloud_disk_encrypted: false, # need to set up kms before setting to true
      alicloud_disk_category: 'cloud_efficiency',
      alicloud_slb_http_name: "slb-http-#{add_random_string}",
      alicloud_slb_http_address_type: 'internet',
      alicloud_slb_https_name: "slb-https-#{add_random_string}",
      alicloud_slb_https_address_type: 'internet',
      alicloud_slb_https_specification: 'slb.s1.small',
      alicloud_slb_server_certificate_name: "slb-cert-#{add_random_string}",
      alicloud_http_listener_fe_port: 80,
      alicloud_http_listener_be_port: 80,
      alicloud_http_listener_protocol: 'http',
      alicloud_http_listener_bandwidth: 1,
      alicloud_https_listener_fe_port: 443,
      alicloud_https_listener_be_port: 443,
      alicloud_https_listener_protocol: 'https',
      alicloud_https_listener_bandwidth: 1,
      alicloud_https_listener_tls_cipher_policy: 'tls_cipher_policy_1_2',
      alicloud_tags: { 'test' => 'tag' },
      alicloud_ram_account_password_policy_password_reuse_prevention: 5,
      alicloud_ram_account_password_policy_max_password_age: 180,
      # Simple flag to disable creation of resources (useful when prototyping new ones in isolation)
      alicloud_enable_create: 1
  }

  def self.config
    @config
  end

  # This method ensures any environment variables take precedence.
  def self.update_from_environment
    @config.each { |k, v| @config[k] = ENV[k.to_s.upcase] || v }
  end

  # Create JSON for terraform
  def self.store_json(file_name = 'alicloud-inspec.tfvars.json')
    update_from_environment
    File.open(File.join(File.dirname(__FILE__), '..', 'build', file_name), 'w') do |f|
      f.write(@config.to_json)
    end
  end

  # Create YAML for inspec
  def self.store_yaml(file_name = 'alicloud-inspec-attributes.yaml')
    update_from_environment
    File.open(File.join(File.dirname(__FILE__), '..', 'build', file_name), 'w') do |f|
      f.write(@config.to_yaml)
    end
  end

  def self.get_tf_output_vars(file_name = 'outputs.tf')
    # let's assume that all lines starting with 'output' contain the desired target name
    # (brittle but this way we don't need to preserve a list)
    outputs = []
    outputs_file = File.join(File.dirname(__FILE__), '..', 'build', file_name)
    File.read(outputs_file).lines.each do |line|
      next if !line.start_with?('output')
      outputs += [line.sub(/^output \"/, "").sub(/\" {\n/, '')]
    end
    outputs
  end

  def self.update_yaml(file_name = 'alicloud-inspec-attributes.yaml')
    build_dir = File.join(File.dirname(__FILE__), '..', 'build')
    contents = YAML.load_file(File.join(build_dir, file_name))
    outputs = get_tf_output_vars
    outputs.each do |tf|
      # also assuming single values here
      value = `cd #{build_dir} && terraform output #{tf}`.strip
      contents[tf.to_sym] = value
    end
    File.open(File.join(File.dirname(__FILE__), '..', 'build', file_name), 'w') do |f|
      f.write(contents.to_yaml)
    end
  end
end