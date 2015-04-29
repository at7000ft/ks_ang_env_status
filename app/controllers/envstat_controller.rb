#
# Title: EnvstatController
# Description: Root controller
#
# Author: rholl00
# Date: 12/10/14
#
require_relative '../../lib/keystone_util'

class EnvstatController < ApplicationController
  REGION_ARRAY_CACHE_KEY = "regionArray"

  #
  # Load array of region name strings
  #
  def index
    @regionArray = getRegionArray
  end

private

  #
  # Return an array of two element strings, display region string and region string
  #
  def getRegionArray
    Rails.cache.fetch(REGION_ARRAY_CACHE_KEY, :expires_in => KeystoneUtil::CACHE_TIMEOUT_LISTS) do
      KeystoneUtil::AWS_REGIONS_SELECT
    end
  end
end
