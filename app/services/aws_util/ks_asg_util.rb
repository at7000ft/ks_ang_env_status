require 'aws-sdk'

require_relative './stack_build_params.rb'
require_relative './ks_ec2_util.rb'
require_relative './ks_cf_util.rb'
require_relative './ks_common'

class KSAsgUtil

  include KSCommon

  def initialize(stackParams)
    @stackParams = stackParams

    #Run the local config.rb script to load AWS props and config AWS with keys and region
    begin
      #File.expand_path(File.dirname(__FILE__) + '/config')
      @asg = Aws::AutoScaling::Client.new(
          :access_key_id => @stackParams.accesskey,
          :secret_access_key => @stackParams.secretkey,
          :region => @stackParams.region)
    rescue Exception => e
      puts "KSAsgUtil>>initialize: error " + e.message
    end
  end

  #
  # Return an array of all ASG object (CF phyids)
  #
  def getAsgs()
    options = Hash.new
    asgs = []
    next_token = 0
    while next_token != nil
      options[:next_token] = next_token unless next_token == 0
      resp = @asg.describe_auto_scaling_groups(options)
      asgs.concat(resp.data[:auto_scaling_groups])
      next_token = resp.data[:next_token]
    end
    asgs
  end

  def getAsgStatusForEnv(env)
    envStatusMap = {}
    asgs = getAsgs
    asgs.each do |asg|
      if asg[:auto_scaling_group_name].downcase.include?('keystone-2-' + env.downcase + '-')
        envStatusMap[asg[:auto_scaling_group_name]] = isAsgSuspended(asg[:auto_scaling_group_name]) ? STATUS_SUSPENDED : STATUS_RUNNING
      end
    end
    envStatusMap
  end

  def isEnvDeployed(env)
    envStatusMap = getAsgStatusForEnv(env)
    return !envStatusMap.empty?
  end

  def isAnyAsgSuspendedForEnv(env)
    envStatusMap = getAsgStatusForEnv(env)
    envStatusMap.values.each do |value|
      if value == STATUS_SUSPENDED
        return true
      end
    end
    return false
  end

  def showAsgs
    puts "ASGs:"
    asgs = getAsgs
    asgs.each do |asg |
      puts "ASG name - #{asg[:auto_scaling_group_name]}"
    end
  end

  def getAsg(physicalId)
    options = Hash.new
    options[:auto_scaling_group_names] = [physicalId]
    asg = @asg.describe_auto_scaling_groups(options)
    return asg.data[:auto_scaling_groups][0]
  end

  def isAsgSuspended(physicalId)
    asg = getAsg(physicalId)
    susArr = asg[:suspended_processes]
    return susArr.size() > 0
  end

  def asgExists(physicalId)
    asg = getAsg(physicalId)
    return asg != nil
  end

  def suspendAsg(physicalId)
    puts "Suspending ASG #{physicalId}"
    options = Hash.new
    options[:auto_scaling_group_name] = physicalId
    #options[:scaling_processes] = 'Launch'
    resp = @asg.suspend_processes(options)
    puts "ASG #{physicalId} suspended"
  end

  def resumeAsg(physicalId)
    puts "Resuming ASG #{physicalId}"
    options = Hash.new
    options[:auto_scaling_group_name] = physicalId
    resp = @asg.resume_processes(options)
    puts "ASG #{physicalId} resumed"
  end

  def getEc2instances(physicalId)
    group = getAsg(physicalId)
    ids = Array.new
    group[:instances].each do |instance|
      ids.push(instance[:instance_id])
    end
    return ids
  end

  def getEc2Info(physicalId)
    group = getAsg(physicalId)
    retHash = Hash.new
    group[:instances].each do |instance|
      infoHash = Hash.new
      infoHash['AsgHealthStatus'] = instance[:health_status]
      infoHash['AsgLifecycleState'] = instance[:lifecycle_state]
      retHash[instance[:instance_id]] = infoHash
    end
    return retHash
  end

end


if __FILE__==$0

  KSDeploy.setTemplatePath(TEMPLATE_PATH)
  KSDeploy.setPropertiesPath(PROPERTIES_PATH)

  stackBuild = StackBuildParams.new
  stackBuild.modparam = nil
  stackBuild.stacks= ['1']
  stackBuild.accesskey = ENV['AWS_ACCESS_KEY']
  stackBuild.alternateregion = 'us-east-1'
  stackBuild.region = 'us-west-2'
  stackBuild.secretkey = ENV['AWS_SECRET_KEY']
  stackBuild.shard = 'Common'
  stackBuild.env = 'dev'
  stackBuild.profile = PROFILE_MEDIUM

  puts "Using #{stackBuild.to_s}"


  util = KSAsgUtil.new(stackBuild)

  util.showAsgs

  # stackSuffix = KSDeploy::LOGSTASH_STACK_SUFFIX
  # logstashAsgPhyId = util.getStackResource(util.getStackname(stackBuild,stackSuffix,nil),"LogstashAutoScalingGroup",nil)
  # group = util.getAsg(logstashAsgPhyId)
  # puts "ASG group - #{group}"

  #util.suspendAsg(logstashAsgPhyId)

  #util.resumeAsg(logstashAsgPhyId)

  # ec2s = util.getEc2instances(logstashAsgPhyId)
  # puts "EC2 instances - #{ec2s}"
  #
  # ec2Util = KSEc2Util.new(stackBuild)
  # ec2Util.terminateInstances(ec2s)

end