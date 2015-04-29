require_relative './ks_ec2_util'
require_relative './ks_rds_util'
require_relative './ks_asg_util'
require_relative './ks_cf_util'
require_relative './stack_build_params'
require_relative './ks_rem_access'

#
# A utility class with convenience methods for AWS service access with knowledge of Keystone CF stacks and
# components.
#
class KSMaintUtil
  # CF Logical ids and output key names of Keystone CF components
  PORTAL_GW_ASG_LOGICAL_ID = "PortalGatewayAutoScalingGroup"
  PORTAL_ASG_LOGICAL_ID = "PortalAutoScalingGroup"
  PORTAL_ELB_URL_OUTPUT_KEY = "PortalURL"
  PORTAL_GW_ELB_URL_OUTPUT_KEY = "PortalGatewayURL"
  SERVICES_ASG_LOGICAL_ID = "RestfulServicesAutoScalingGroup"
  KERNEL1_ASG_LOGICAL_ID = "KernelAutoScalingGroup1"
  KERNEL2_ASG_LOGICAL_ID = "KernelAutoScalingGroup2"
  KERNEL3_ASG_LOGICAL_ID = "KernelAutoScalingGroup3"
  KERNEL4_ASG_LOGICAL_ID = "KernelAutoScalingGroup4"
  BATCH_ASG_LOGICAL_ID = "BatchAutoScalingGroup"
  BASTION_LOGICAL_ID = "BastionHost"
  S3_BUCKET_NAME_OUTPUT_KEY = "BucketName"
  LOGSTASH_ASG_LOGICAL_ID = "LogstashAutoScalingGroup"
  SERVICES_GW_ELB_URL_OUTPUT_KEY = "KeystoneServicesSecurityGatewayURL"
  LOGSTASH_ELB_URL_OUTPUT_KEY = "LogstashURL"
  SERVICES_SGW_ASG_LOGICAL_ID = "SecurityGatewayAutoScalingGroup"
  MIGRATION_LOGICAL_ID = "MigrationServer"
  DB_USER_NAME = "bhnuser"

  NAGIFT_SHARD = "NAGift"
  IGIFT_SHARD = "IGift"
  COMMON_SHARD = "Common"

  COMMON_ASG_LOGICAL_IDS = {'Portal' => 'PortalAutoScalingGroup',
                            'ServicesSGW' => 'SecurityGatewayAutoScalingGroup',
                            'PortalGW' => 'PortalGatewayAutoScalingGroup'}

  COMMON_EC2_LOGICAL_IDS = {}

  GIFT_ASG_LOGICAL_IDS = {'Batch' => 'BatchAutoScalingGroup',
                          'Kernel1' => 'KernelAutoScalingGroup1',
                          'Kernel2' => 'KernelAutoScalingGroup2',
                          'Kernel3' => 'KernelAutoScalingGroup3',
                          'Kernel4' => 'KernelAutoScalingGroup4',
                          'Services' => 'RestfulServicesAutoScalingGroup'
  }

  GIFT_EC2_LOGICAL_IDS = {'Bastion' => 'BastionHost'
  }


  #
  # Init
  #
  def initialize(stackParams)
    @stackParams = stackParams
    begin
      @ec2Util = KSEc2Util.new(@stackParams)
      @rdsUtil = KSRdsUtil.new(@stackParams)
      @asgUtil = KSAsgUtil.new(@stackParams)
      @cfUtil = KSCfUtil.new(@stackParams)

      puts ""
    rescue Exception => e
      puts "KSMaintUtil>>initialize: error " + e.message
      raise StandardError.new("KSMaintUtil>>initialize: error  #{e.message}");
    end
  end

  #
  # Return an Array of Keystone environment names currently deployed to CF
  #
  def getDeployedEnvs()
    envArray = Array.new
    stacks = @cfUtil.getKeystoneStacks('keystone-2-')
    stacks.each do |stack|
      stk = stack.downcase
      if stk.include? '-common-'
        env = stk.split('keystone-2-').last.partition('-common').first
      elsif stk.include? '-nagift-'
        env = stk.split('keystone-2-').last.partition('-nagift').first
      elsif stk.include? '-igift-'
        env = stk.split('keystone-2-').last.partition('-igift').first
      elsif stk.include? '-cloop-'
        env = stk.split('keystone-2-').last.partition('-cloop').first
      else
        puts "getDeployedEnvs: Error: keystone-2- not found in stack name #{stack}"
      end
      envArray << env.upcase unless env.nil?
    end
    envArray.uniq
  end

  #
  # Return the status of all ASGs in an environment 'Running' or 'Suspended'
  #
  def getEnvAsgStatus(env)
    asgStatusMap = {}
    asgs = @asgUtil.getAsgs
    asgs.each do |asg|
      if asg[:auto_scaling_group_name].downcase.include?('keystone-2-' + env.downcase + '-')
        asgStatusMap[asg[:auto_scaling_group_name]] = @asgUtil.isAsgSuspended(asg[:auto_scaling_group_name]) ? KSAsgUtil::STATUS_SUSPENDED : KSAsgUtil::STATUS_RUNNING
      end
    end
    asgStatusMap
  end

  #
  # Return a Hash of env=>status given an array of envs, status is based on whether any asg is suspended
  #
  def getEnvsStatus(envArray)
    envStatusMap = Hash.new
    envArray.each do |env|
      envStatusMap[env] = KSAsgUtil::STATUS_RUNNING
      asgStatusMap = getEnvAsgStatus(env)
      asgStatusMap.each do |asg, status|
        if status == KSAsgUtil::STATUS_SUSPENDED
          envStatusMap[env] = KSAsgUtil::STATUS_SUSPENDED
          break
        end
      end
    end
    envStatusMap
  end

  def envStatus(env)
    if !isEnvDeployed(env)
      return STATUS_ENV_PARTIALLY_DEPLOYED
    elsif isEnvShutdown(env)
      return STATUS_ENV_SHUTDOWN
    else
      return STATUS_ENV_RUNNING
    end
  end

  def isEnvShutdown(env)
    return @asgUtil.isAnyAsgSuspendedForEnv(env)
  end

  #
  # Suspend an enviroment
  #
  def suspendEnv()
    puts "Suspending env #{@stackParams.env}"
    @stackParams.shard = COMMON_SHARD
    COMMON_ASG_LOGICAL_IDS.each do |stackSuffix, asgLogicalId|
      suspendAsg(stackSuffix, asgLogicalId)
    end
    COMMON_EC2_LOGICAL_IDS.each do |stackSuffix, ec2LogicalId|
      stopInstance(ec2LogicalId, stackSuffix)
    end

    [NAGIFT_SHARD, IGIFT_SHARD].each do |shard|
      @stackParams.shard = shard
      GIFT_ASG_LOGICAL_IDS.each do |stackSuffix, asgLogicalId|
        suspendAsg(stackSuffix, asgLogicalId)
      end
      GIFT_EC2_LOGICAL_IDS.each do |stackSuffix, ec2LogicalId|
        stopInstance(ec2LogicalId, stackSuffix)
      end
    end
    puts "Env #{@stackParams.env} suspend complete"
  end

  #
  # Start an enviroment
  #
  def startEnv()
    puts "Starting env #{@stackParams.env}"
    #Map of asg phyId=>Array[terminatedInstanceIds]
    @terminatedInstIdMap = Hash.new


    # Resume ASGs and start EC2 instances
    @stackParams.shard = COMMON_SHARD
    COMMON_ASG_LOGICAL_IDS.each do |stackSuffix, asgLogicalId|
      resumeAsg(stackSuffix, asgLogicalId)
    end
    COMMON_EC2_LOGICAL_IDS.each do |stackSuffix, ec2LogicalId|
      startInstance(ec2LogicalId, stackSuffix)
    end
    [NAGIFT_SHARD, IGIFT_SHARD].each do |shard|
      @stackParams.shard = shard
      GIFT_ASG_LOGICAL_IDS.each do |stackSuffix, asgLogicalId|
        resumeAsg(stackSuffix, asgLogicalId)
      end
      GIFT_EC2_LOGICAL_IDS.each do |stackSuffix, ec2LogicalId|
        startInstance(ec2LogicalId, stackSuffix)
      end
    end

    #Wait for all EC2 to attain running state
    @stackParams.shard = COMMON_SHARD
    COMMON_ASG_LOGICAL_IDS.each do |stackSuffix, asgLogicalId|
      waitForNewInstanceCompletion(stackSuffix, asgLogicalId)
    end

    [NAGIFT_SHARD, IGIFT_SHARD].each do |shard|
      @stackParams.shard = shard
      GIFT_ASG_LOGICAL_IDS.each do |stackSuffix, asgLogicalId|
        waitForNewInstanceCompletion(stackSuffix, asgLogicalId)
      end

    end

    puts "Env #{@stackParams.env} start complete"
  end


  def suspendAsg(stackSuffix, asgLogicalId)
    stackname = KSCfUtil.getStackname(@stackParams, stackSuffix, nil)
    asgPhyId = @cfUtil.getStackResource(stackname, asgLogicalId, nil)
    if asgPhyId.nil?
      puts "ASG #{asgLogicalId} not found in stack #{stackname}"
      return
    end
    @asgUtil.suspendAsg(asgPhyId)
    terminateAsgEc2s(asgPhyId)
  end

  #
  # Resume the ASG asgLogicalId within CF stack stackSuffix
  # After resume wait for removal of terminated instances then for creation of new instances.
  #
  def resumeAsg(stackSuffix, asgLogicalId)
    stackname = KSCfUtil.getStackname(@stackParams, stackSuffix, nil)
    puts "\nResuming ASG #{asgLogicalId} in stack #{stackname}  "
    asgPhyId = @cfUtil.getStackResource(stackname, asgLogicalId, nil)

    if asgPhyId.nil?
      puts "ASG #{asgLogicalId} not found in stack #{stackname}"
      return
    end
    isSuspended = @asgUtil.isAsgSuspended(asgPhyId)
    unless isSuspended
      puts "ASG #{asgPhyId} is currently unsuspended"
      @terminatedInstIdMap[asgPhyId] = Array.new
      return
    end
    @terminatedInstIdMap[asgPhyId] = @asgUtil.getEc2instances(asgPhyId)
    @asgUtil.resumeAsg(asgPhyId)
  end


  def terminateAsgEc2s(asgPhyId)
    ec2s = @asgUtil.getEc2instances(asgPhyId)
    if ec2s.length > 0
      @ec2Util.terminateInstances(ec2s)
      ec2s.each do |ec2|
        stat = @ec2Util.waitForInstanceNotRunning(ec2)
        if stat == KSEc2Util::WAIT_TIMEOUT
          ec2s = @asgUtil.getEc2instances(asgPhyId)
          ec2s.each do |newec2|
            @ec2Util.waitForInstanceNotRunning(newec2)
          end
        end
      end
    end
  end

  def waitForNewInstanceCompletion(stackSuffix, asgLogicalId)
    stackname = KSCfUtil.getStackname(@stackParams, stackSuffix, nil)
    #puts "\nWaiting for instance resumption for  #{asgLogicalId} in stack #{stackname}  "

    asgPhyId = @cfUtil.getStackResource(stackname, asgLogicalId, nil)
    if asgPhyId.nil?
      #puts "ASG not found in stack @{stackname} with logical id #{asgLogicalId}"
      return
    end
    termEc2s = @terminatedInstIdMap[asgPhyId]
    if termEc2s.nil? || termEc2s.empty?
      #puts "No ec2 instances or asg #{asgLogicalId} in stack #{stackSuffix} found"
      return
    end
    puts "Terminated instances waiting for removal - #{termEc2s}"
    if termEc2s.length > 0
      newec2s = @asgUtil.getEc2instances(asgPhyId)

      #Loop waiting for ASG to remove terminated instances (newec2s will contain no elements of termEc2s)
      while (termEc2s - newec2s).size() < termEc2s.size() do
        newec2s = @asgUtil.getEc2instances(asgPhyId)
        puts "newec2s - #{newec2s}"
        sleep(10)
        puts "Waiting for ASG #{asgLogicalId} to remove terminated instances"
      end
      #Loop waiting for ASG to create new instances
      while newec2s.size() == 0
        puts "Waiting for ASG #{asgLogicalId} to create new running instances"
        newec2s = @asgUtil.getEc2instances(asgPhyId)
        sleep(10)
      end
      puts "New instances created - #{newec2s}"


      newec2s.each do |newec2|
        stat = @ec2Util.waitForInstanceRunning(newec2)
        if stat == KSEc2Util::WAIT_TIMEOUT
          puts "Timeout waiting for #{newec2} to reach running state"
        end
      end
    end
  end

  #
  # Stop an ec2 instance referenced in a CF stack, wait till instance stopped before returning
  #
  def stopInstance(cfLogicalId, stackSuffix)
    instId = getEc2InstId(cfLogicalId, stackSuffix)
    if instId.nil?
      puts "Instance id for #{cfLogicalId} stack #{stackSuffix} was not found"
      return
    end
    ids = [instId]
    @ec2Util.stopInstances(ids)
    @ec2Util.waitForInstanceNotRunning(instId)
    puts "Instance #{instId} stopped"
  end

  #
  # Return the instid of an ec2 instance referenced in a CF stack
  #
  def getEc2InstId(cfLogicalId, stackSuffix)
    instId = @cfUtil.getStackResource(KSCfUtil.getStackname(@stackParams, stackSuffix, nil), cfLogicalId, nil)
    return instId
  end

  #
  # Start an ec2 instance referenced in a CF stack, wait till instance stopped before returning
  #
  def startInstance(cfLogicalId, stackSuffix)
    instId = getEc2InstId(cfLogicalId, stackSuffix)
    if instId.nil?
      puts "Instance id for #{cfLogicalId} stack #{stackSuffix} was not found"
      return
    end
    ids = [instId]
    @ec2Util.startInstances(ids)
    @ec2Util.waitForInstanceRunning(instId)
    puts "Instance #{instId} running"
  end

  #
  # Return an array of ec2 instance ids associated with an ASG referenced in a CF stack
  #
  def ecs2sFromAsg(stackSuffix, asgLogicalId)
    asgPhyId = @cfUtil.getStackResource(KSCfUtil.getStackname(@stackParams, stackSuffix, nil), asgLogicalId, nil)
    if asgPhyId.nil?
      puts "ASG #{asgLogicalId} not found in stack #{stackSuffix}"
      return
    end
    portalGwEc2s = @asgUtil.getEc2instances(asgPhyId)
    return portalGwEc2s
  end

  #
  # Return the ASG health_status and lifecycle_state of all ec2s managed by an ASG
  #
  def asgEc2Info(stackSuffix, asgLogicalId)
    asgPhyId = @cfUtil.getStackResource(KSCfUtil.getStackname(@stackParams, stackSuffix, nil), asgLogicalId, nil)
    if asgPhyId.nil?
      puts "ASG #{asgLogicalId} not found in stack #{stackSuffix}"
      return
    end
    asgEc2Hash = @asgUtil.getEc2Info(asgPhyId)
    return asgEc2Hash
  end

  #
  # Test for the existance of an ASG specified within a CF stack
  #
  def asgExists(stackSuffix, asgLogicalId)
    asgPhyId = @cfUtil.getStackResource(KSCfUtil.getStackname(@stackParams, stackSuffix, nil), asgLogicalId, nil)
    return asgPhyId != nil
  end

  #
  # Return an array of Hashes with info about each ec2 instance including asg status managed by the asgLogicalId ASG
  #
  def getAsgEc2Info(title, stackSuffix, asgLogicalId, absoluteKeyPath)
    ec2IpAdder = nil
    ec2Array = []
    unless asgExists(stackSuffix, asgLogicalId)
      return ec2Array
    end
    ec2s = ecs2sFromAsg(stackSuffix, asgLogicalId)
    if ec2s.nil? || ec2s.size() == 0
      return ec2Array
    end
    #Load asg status for each ec2
    asgEc2InfoHash = asgEc2Info(stackSuffix, asgLogicalId)
    #Add ec2 info for each instance
    ec2s.each do |ec2id|
      infoHash = @ec2Util.getInstanceData(ec2id)
      if infoHash != nil
        infoHash.each do |key, value|
          if key == 'IPAddress'
            ec2IpAdder = value
          end
        end
        #Retrive version files from this host and add
        unless ec2IpAdder.nil?
          rem = KsRemAccess.new(ec2IpAdder, absoluteKeyPath)
          versionArray = rem.getRemoteVersionFileNames('/var/tmp')
          if versionArray.empty?
            infoHash["Versions"] = "Not Found"
          else
            infoHash["Versions"] = versionArray
          end
        end
        infoHash.merge!(asgEc2InfoHash[ec2id])
        ec2Array << infoHash
      end
    end

    ec2Array

  end

  #
  # Return a Hash of ec2 info for the instance referenced by a CF stack
  #
  def getEc2Info(title, stackSuffix, cfLogicalId, absoluteKeyPath)
    ec2IpAdder = nil
    ec2Array = []
    instId = getEc2InstId(cfLogicalId, stackSuffix)
    if instId.nil?
      return ec2Array
    end
    infoHash = @ec2Util.getInstanceData(instId)
    unless infoHash.nil?
      infoHash.each do |key, value|
        if key == 'IPAddress'
          ec2IpAdder = value
        end
      end
      #Retrive version files from this host and add
      unless ec2IpAdder.nil?
        rem = KsRemAccess.new(ec2IpAdder, absoluteKeyPath)
        versionArray = rem.getRemoteVersionFileNames('/var/tmp')
        if versionArray.empty?
          infoHash["Versions"] = "Not Found"
        else
          infoHash["Versions"] = versionArray
        end
      end
      ec2Array << infoHash
    end

    ec2Array
  end


  #
  # Return true if any asgs are deployed for the env
  #
  def isEnvDeployed(env)
    return @asgUtil.isEnvDeployed(env)
  end


  #
  # Return the S3 bucket name associated with the S3 CF stack using @stackParams parameters
  #
  def getS3BucketName()
    bname = @cfUtil.getStackOutput(KSCfUtil.getStackname(@stackParams, KSCfUtil::S3_STACK_SUFFIX, nil), S3_BUCKET_NAME_OUTPUT_KEY)
    if bname.nil?
      return 'Not Found'
    end
    bname
  end
end

if __FILE__==$0
  #KSDeploy.setTemplatePath(KSDeploy::TEMPLATE_PATH)
  # KSDeploy.setPropertiesPath(KSDeploy::PROPERTIES_PATH)

  stackParams = StackBuildParams.new
  stackParams.modparam = nil
  stackParams.stacks= ['1']
  stackParams.accesskey = ENV['AWS_ACCESS_KEY']
  stackParams.region = 'us-west-2'
  stackParams.secretkey = ENV['AWS_SECRET_KEY']
  stackParams.shard = 'NAGift'
  stackParams.env = 'dev'
  stackParams.profile = 'medium'

  puts "Starting"
  begin
    maintUtil = KSMaintUtil.new(stackParams)

    envs = maintUtil.getDeployedEnvs()
    puts "Envs in region #{stackParams.region} - #{envs}"
  rescue StandardError => error
    puts "Error: KSMaintUtil - #{error.message}";
    exit
  end

  #maintUtil.startEnv()

  #bastionLogicalId = 'BastionHost'
  #stackSuffix = KSDeploy::BASTION_STACK_SUFFIX
  #maintUtil.stopInstance(bastionLogicalId, stackSuffix)

  #maintUtil.startInstance(bastionLogicalId,stackSuffix)

  # maintUtil.showShardInfoHeader()
  # maintUtil.showCommonShardInfo()
  # maintUtil.showShardInfo(KSDeploy::NAGIFT_SHARD)
  # maintUtil.showShardInfo(KSDeploy::IGIFT_SHARD)

  #instId = maintUtil.getEc2InstId('BastionHost', 'Bastion')
  #p instId

  # envStatusMap = maintUtil.getEnvsStatus(envs)
  # envStatusMap.each do |env, status|
  #   puts "#{env} - #{status}"
  # end

  puts "Done"


end