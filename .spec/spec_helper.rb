# frozen_string_literal: true

require 'net/http'
require 'socket'
require 'timeout'
require 'json'
require 'yaml'

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.shared_context_metadata_behavior = :apply_to_host_groups
end

def http
  language = ENV.fetch('LANGUAGE')
  framework = ENV.fetch('FRAMEWORK')
  engine = ENV.fetch('ENGINE')

  Net::HTTP.new(benchmark_target_ip(language, framework, engine), 3000)
end

# Resolve the IP rspec should hit, guarding against a stale per-run ip/cid file
# silently pointing the suite at a DIFFERENT container than the one just built
# for the framework under test.
def benchmark_target_ip(language, framework, engine)
  dir = File.join(language, framework)
  ip_file = File.join(dir, "ip-#{engine}.txt")

  raise TargetError, "#{ip_file} not found — run `make build` for #{dir} before testing." unless File.exist?(ip_file)

  ip = File.read(ip_file).strip
  raise TargetError, "#{ip_file} is empty — the build step recorded no container IP." if ip.empty?

  verify_fresh_container(dir, engine, language, framework, ip)
  verify_reachable(ip, ip_file)

  ip
end

class TargetError < StandardError; end

# For the docker provider, the freshly-started container id is recorded in the
# cid file. Re-derive the truth from it and fail loudly if the recorded ip no
# longer matches, if the container is gone/stopped, or if it was built from a
# different framework's image — all signatures of a stale ip/cid file.
# Providers without a cid file (e.g. cloud) skip these checks.
def verify_fresh_container(dir, engine, language, framework, ip)
  cid_file = File.join(dir, "cid-#{engine}.txt")
  return unless File.exist?(cid_file)
  return unless system('docker version > /dev/null 2>&1')

  cid = File.read(cid_file).strip
  return if cid.empty?

  raw = `docker inspect #{cid} 2>/dev/null`
  raise TargetError, "container #{short(cid)} from #{cid_file} no longer exists — re-run `make build` for #{dir}." if raw.strip.empty?

  container = JSON.parse(raw).first
  expected_image = "#{language}.#{framework}.#{engine}"
  image = container.dig('Config', 'Image')
  current_ip = container.dig('NetworkSettings', 'Networks', 'bridge', 'IPAddress')

  unless container.dig('State', 'Running')
    raise TargetError, "container #{short(cid)} (#{image}) is not running — re-run `make build` for #{dir}."
  end

  if image != expected_image
    raise TargetError,
          "#{cid_file} points at container #{short(cid)} built from '#{image}', but the framework under " \
          "test is '#{expected_image}'. Stale cid/ip file — re-run `make build` for #{dir}."
  end

  if current_ip && !current_ip.empty? && current_ip != ip
    raise TargetError,
          "#{dir}/ip-#{engine}.txt records #{ip}, but container #{short(cid)} (#{expected_image}) is now at " \
          "#{current_ip}. Stale ip file — re-run `make build` for #{dir}."
  end
end

def verify_reachable(ip, ip_file)
  Timeout.timeout(5) { TCPSocket.new(ip, 3000).close }
rescue StandardError => e
  raise TargetError,
        "target #{ip}:3000 (from #{ip_file}) is unreachable — #{e.class}: #{e.message}. " \
        'The container may not be running; re-run `make build`.'
end

def short(cid)
  cid[0, 12]
end
