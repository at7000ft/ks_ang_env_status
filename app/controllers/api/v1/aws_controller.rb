#
# Title: AwsController
# Description: A REST/JSON API controller returning current environment and shard status
#
# Author: rholl00 
# Date: 1/7/15
#

require_relative '../../../../lib/keystone_util'

require_relative '../../../services/aws_util/stack_build_params'
require_relative '../../../services/aws_access'
require 'rufus-scheduler'

module Api
  module V1
    class AwsController < ActionController::Base



      def initialize
        puts "AwsController>>initialize: running"
        scheduler = Rufus::Scheduler.new
        scheduler.every '6h' do
          puts "AwsController>>initialize: load cache running"
          region = 'us-west-2'
          envArray = getEnvArray(region)
          Rails.cache.fetch(KeystoneUtil::STATUS_MAP_KEY_PREFIX + '-' + region, :expires_in => KeystoneUtil::CACHE_TIMEOUT_STACKS) do
            AwsAccess.getEnvsStatus(envArray, AwsAccess.getStackBuild(nil, region, nil))
          end
        end
        @shardLookupMap = {'common' => 'Common', 'nagift' => 'NAGift', 'igift' => 'IGift', 'cloop' => 'CLoop'}
      end

      #Add some http headers to all outgoing responses to allow localhost testing
      after_filter :cors_set_access_control_headers

      #
      # Return a JSON array containing the suspended/running status of all deployed environments in a region.
      # Load result into Rails cache.
      # Access at http://localhost:3000/api/v1/envsStatus.
      #
      def envsStatus
        region = params['region']
        if region.nil?
          puts "envsStatus: Error - no region specified "
          head :unprocessable_entity
        end
        puts "envsStatus: called with params - #{region}"

        envArray = getEnvArray(region)
        @envStatusMap = Rails.cache.fetch(KeystoneUtil::STATUS_MAP_KEY_PREFIX + '-' + region, :expires_in => KeystoneUtil::CACHE_TIMEOUT_STACKS) do
          AwsAccess.getEnvsStatus(envArray, AwsAccess.getStackBuild(nil, region, nil))
        end
        render json: @envStatusMap

        # If error - render json: {:errors => ['Bad stufff']}, :status => 422
        # Check errors on client - var errors = JSON(xhr.responseTest).errors
      end

      #
      # Return a JSON object containing EC2/RDS/ASG status for a shard in a region and environment.
      # Access at http://localhost:3000/api/v1/shardStatus
      #
      def shardStatus
        puts "shardStatus: called with params - #{params['region']} - #{params['env']} - #{params['shard']}"
        #Cap first letter of shardname in stackbuild
        stackBuild = AwsAccess.getStackBuild(params['env'], params['region'], @shardLookupMap[params[:shard].downcase])

        case params[:shard].downcase
          when 'common'
            @shard_info = Rails.cache.fetch(stackBuild.getCacheKey, :expires_in => KeystoneUtil::CACHE_TIMEOUT_STACKS) do
              AwsAccess.getCommonStatus(stackBuild)
            end

          when 'nagift', 'igift', 'cloop'
            @shard_info = Rails.cache.fetch(stackBuild.getCacheKey, :expires_in => KeystoneUtil::CACHE_TIMEOUT_STACKS) do
              AwsAccess.getGiftStatus(stackBuild)
            end
          else
            puts "Invalid shard received - #{params[:shard]}"
        end
        render json: @shard_info
      end

      #
      # Flush Rails caches containing region/env/shard status
      # Access at http://localhost:3000/api/v1/flushCaches
      #
      def flushCaches
        shard = params['shard']
        region = params['region']
        env = params['env']
        puts "flushCaches: called with #{shard} #{region} #{env}"
        case shard
          when "all"
            Rails.cache.clear
          when "common","igift","nagift"
            stackBuild = AwsAccess.getStackBuild(env, region, @shardLookupMap[shard.downcase])
            Rails.cache.delete(stackBuild.getCacheKey)
          else
            puts "Invalid shard value received - #{shard}"
        end
        #Rails.cache.clear
        render json: {}

        #Render a test error (returns an object with a 'message' variable with the error string)
        #render :json => {:message => "Something bad just happened "}, :status => 500
      end

      #
      # Start an environment in a region.
      # Access at http://localhost:3000/api/v1/startEnv
      #
      def startEnv
        #puts "startEnv: called with params - #{params.region} - #{params.env}"
        puts "startEnv: called with params - #{params}"
        AwsAccess.startEnv(AwsAccess.getStackBuild(params['env'], params['region'], nil))
        #sleep(5)
        #Reload the status for the started env
        loadEnvStatusForEnv(params['env'], params['region'])
        render json: {}
      end


      #Access at http://localhost:3000/api/v1/stopEnv
      def stopEnv
        puts "stopEnv: called with params - #{params['region']} - #{params['env']}"
        AwsAccess.stopEnv(AwsAccess.getStackBuild(params['env'], params['region'], nil))
        #sleep(5)
        #Reload the status for the stopped env
        loadEnvStatusForEnv(params['env'], params['region'])
        render json: {}
      end

      #Access at http://localhost:3000/api/v1/regions
      def regions
        puts "regions: called with params - #{params}"

        render json: KeystoneUtil::AWS_REGIONS_SELECT
      end

      private

      def getEnvArray(region)
        Rails.cache.fetch(KeystoneUtil::ENVIRONMENT_ARRAY_CACHE_KEY_PREFIX + '-' + region, :expires_in => KeystoneUtil::CACHE_TIMEOUT_LISTS) do
          AwsAccess.getDeployedEnvs(AwsAccess.getStackBuild(nil, region, nil))
        end
      end

      def loadEnvStatus(region, envArray)
        @envStatusMap = Rails.cache.fetch(KeystoneUtil::STATUS_MAP_KEY_PREFIX + '-' + region, :expires_in => KeystoneUtil::CACHE_TIMEOUT_STACKS) do
          AwsAccess.getEnvsStatus(envArray, AwsAccess.getStackBuild(nil, region, nil))
        end
      end

      def loadEnvStatusForEnv(env, region)
        @envStatusMap = loadEnvStatus(region, getEnvArray(region))
        singleEnvArray = [env]
        singleEnvStatus = AwsAccess.getEnvsStatus(singleEnvArray, AwsAccess.getStackBuild(env, region, nil))
        puts "singleEnvStatus: #{singleEnvStatus}"
        @envStatusMap[env] = singleEnvStatus[env]
        Rails.cache.write(KeystoneUtil::STATUS_MAP_KEY_PREFIX + '-' + region, @envStatusMap, :expires_in => KeystoneUtil::CACHE_TIMEOUT_STACKS)

      end

      # def getStackBuild(env, region, shard)
      #   stackBuild = StackBuildParams.new
      #   stackBuild.modparam = nil
      #   stackBuild.stacks= ['1']
      #   stackBuild.accesskey = ENV['AWS_ACCESS_KEY']
      #   stackBuild.region = region
      #   stackBuild.secretkey = ENV['AWS_SECRET_KEY']
      #   stackBuild.shard = shard
      #   stackBuild.env = env.downcase unless env.nil?
      #   stackBuild
      # end

      # For all responses in this controller, return the CORS access control headers.
      # Needed for localhost testing
      def cors_set_access_control_headers
        headers['Access-Control-Allow-Origin'] = '*'
        headers['Access-Control-Allow-Methods'] = 'POST, GET, OPTIONS'
        headers['Access-Control-Allow-Headers'] = %w{Origin Accept Content-Type X-Requested-With X-CSRF-Token}.join(',')
        headers['Access-Control-Max-Age'] = "1728000"
      end


    end
  end
end