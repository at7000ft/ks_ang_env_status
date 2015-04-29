require 'aws-sdk'
require_relative './stack_build_params.rb'
require_relative './ks_ec2_util.rb'
require_relative './ks_cf_util.rb'


class KSAsgUtil
  STATUS_RUNNING = 'Running'
  STATUS_SUSPENDED = 'Suspended'


  def initialize(stackParams)
    @stackParams = stackParams

    #Run the local config.rb script to load AWS props and config AWS with keys and region
    begin
      #File.expand_path(File.dirname(__FILE__) + '/config')
      @asg = AWS::AutoScaling.new(
          :access_key_id => @stackParams.accesskey,
          :secret_access_key => @stackParams.secretkey,
          :region => @stackParams.region)
    rescue Exception => e
      puts "KSAsgUtil>>initialize: error " + e.message
      raise StandardError.new("KSAsgUtil>>initialize: error  #{e.message}");
    end
  end


  #
  # Print all ASGs within the current AWS account
  #
  def showAsgs
    asgs = getAsgs()
    puts "#{asgs.size} ASGs:"
    asgs.each do |asg|
      puts "ASG name - #{asg[:auto_scaling_group_name]}"
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
      resp = @asg.client.describe_auto_scaling_groups(options)
      asgs.concat(resp.data[:auto_scaling_groups])
      next_token = resp.data[:next_token]
    end
    asgs
  end

  def getAsg(physicalId)
    options = Hash.new
    options[:auto_scaling_group_names] = [physicalId]
    asg = @asg.client.describe_auto_scaling_groups(options)
    return asg.data[:auto_scaling_groups][0]
  end

  def isAsgSuspended(physicalId)
    asg = getAsg(physicalId)
    susArr = asg[:suspended_processes]
    return susArr.size() > 0
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

  #
  # Return true if any asgs are deployed for the env
  #
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

  def asgExists(physicalId)
    asg = getAsg(physicalId)
    return asg != nil
  end

  def suspendAsg(physicalId)
    puts "Suspending ASG #{physicalId}"
    options = Hash.new
    options[:auto_scaling_group_name] = physicalId
    #options[:scaling_processes] = 'Launch'
    resp = @asg.client.suspend_processes(options)
    puts "ASG #{physicalId} suspended"
  end

  def resumeAsg(physicalId)
    puts "Resuming ASG #{physicalId}"
    options = Hash.new
    options[:auto_scaling_group_name] = physicalId
    resp = @asg.client.resume_processes(options)
    puts "ASG #{physicalId} resumed"
  end

  #
  # Return a list of ec2 instances managed by the ASG physicalId
  #
  def getEc2instances(physicalId)

    ids = Array.new
    group = getAsg(physicalId)
    unless group.nil?
      group[:instances].each do |instance|
        ids.push(instance[:instance_id])
      end
    end
    return ids
  end

  #
  # Return the ASG health_status and lifecycle_state of all ec2s managed by an ASG
  #
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

  # KSDeploy.setTemplatePath(KSDeploy::TEMPLATE_PATH)
  # KSDeploy.setPropertiesPath(KSDeploy::PROPERTIES_PATH)

  stackBuild = StackBuildParams.new
  stackBuild.modparam = nil
  stackBuild.stacks= ['1']
  stackBuild.accesskey = ENV['AWS_ACCESS_KEY']
  stackBuild.region = 'us-west-2'
  stackBuild.secretkey = ENV['AWS_SECRET_KEY']
  stackBuild.shard = 'Common'
  stackBuild.env = 'dev'
  stackBuild.profile = 'medium'

  puts "Using #{stackBuild.to_s}"


  util = KSAsgUtil.new(stackBuild)
  cf = KSCfUtil.new(stackBuild)

  #util.showAsgs

  stackSuffix = "Logstash"

  logstashAsgPhyId = cf.getStackResource(KSCfUtil.getStackname(stackBuild, stackSuffix, nil), "LogstashAutoScalingGroup", nil)

  #logstashAsgPhyId = "Keystone-2-DEV-Common-Logstash-LogstashAutoScalingGroup-JNUPV3VEG6DX"
  asgPhyId = 'Keystone-2-DEV-Common-Portal-PortalLaunchConfig-Z3KRHHCSUXQM'

  # group = util.getAsg(asgPhyId)
  # puts "ASG object - #{group}"

  # envStatusMap = {}
  # asgs = util.getAsgs
  # asgs.each do |asg|
  #   if asg[:auto_scaling_group_name].downcase.include?('keystone-2-' + stackBuild.env.downcase + '-')
  #     envStatusMap[asg[:auto_scaling_group_name]] = util.isAsgSuspended(asg[:auto_scaling_group_name]) ? 'Suspended' : 'Running'
  #   end
  #   #puts "#{asg[:auto_scaling_group_name]} suspended? -  #{util.isAsgSuspended(asg[:auto_scaling_group_name])}"
  # end
  # envStatusMap.each do |name, status|
  #   puts "#{name} - #{status}"
  # end

  envStatusMap = util.getAsgStatusForEnv(stackBuild.env)
  envStatusMap.each do |name, status|
    puts "#{name} - #{status}"
  end

  #util.suspendAsg(logstashAsgPhyId)

  #util.resumeAsg(logstashAsgPhyId)

  # ec2s = util.getEc2instances(logstashAsgPhyId)
  # puts "EC2 instances - #{ec2s}"
  #
  # ec2Util = KSEc2Util.new(stackBuild)
  # ec2Util.terminateInstances(ec2s)

end