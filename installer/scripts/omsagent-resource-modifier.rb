#!/usr/local/bin/ruby
# frozen_string_literal: true

require "json"
require_relative "microsoft/omsagent/plugin/KubernetesApiClient"

omsagentDs = JSON.parse(KubernetesApiClient.getKubeResourceInfo("omsagent").body)
