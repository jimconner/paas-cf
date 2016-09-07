#!/usr/bin/env ruby

require 'json'
require 'yaml'

class QuotasSetter
  def initialize(manifest)
    @manifest = manifest
  end

  def apply!
    @manifest.fetch("properties").fetch("cc").fetch("quota_definitions").each do |name, definition|
      create_update_quota(name, definition)
    end
  end

private

  def create_update_quota(name, definition)
    args = []
    definition.each do |param, value|
      case param
      when "memory_limit"
        args << '-m' << "#{value}M"
      when "total_services"
        args << '-s' << value.to_s
      when "total_routes"
        args << '-r' << value.to_s
      when "non_basic_services_allowed"
        args << (value ? '--allow-paid-service-plans' : '--disallow-paid-service-plans')
      end
    end
    if existing_quotas.include?(name)
      cf("update-quota", name, *args)
    else
      cf("create-quota", name, *args)
    end
  end

  def existing_quotas
    @existing_quotas ||= fetch_quotas
  end

  def fetch_quotas
    quotas = []
    headers_done = false
    `cf quotas`.each_line do |line|
      unless headers_done
        headers_done = true if line =~ /\Aname\s+/
        next
      end
      if line =~ /\A(\S+)\s+/
        quotas << $1
      end
    end
    quotas
  end

  def cf(*args)
    unless system("cf", *args)
      raise "Error: 'cf #{args.join(' ')}' exited #{$?.exitstatus}"
    end
  end
end

if __FILE__ == $0
  abort "Usage: #{$0} /path/to/manifest.yml" unless ARGV.size == 1
  manifest = YAML.load_file(ARGV[0])
  QuotasSetter.new(manifest).apply!
end
