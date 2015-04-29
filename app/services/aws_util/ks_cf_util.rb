require 'aws-sdk'

require_relative './stack_build_params.rb'


class KSCfUtil
  #Stack suffixes
  ROLES_STACK_SUFFIX = "Roles"
  S3_STACK_SUFFIX = "S3"
  DB_PARAMETERS_STACK_SUFFIX="DBParameters"
  DB_STACK_SUFFIX = "DB"
  REPLICA_DB_PARAMETERS_STACK_SUFFIX="ReplicaDBParameters"
  REPLICA_DB_STACK_SUFFIX = "ReplicaDB"
  LOG_DB_STACK_SUFFIX = "LogDB"
  TRANSIENT_STACK_SUFFIX = "Transient"
  LOG_DB_TRANSIENT_STACK_SUFFIX = "LogDBTransient"
  SECGRP_STACK_SUFFIX = "SecGrp"
  ENI_STACK_SUFFIX = "ENI"
  ELBS_STACK_SUFFIX = "ELBs"
  SERVICES_STACK_SUFFIX = "Services"
  SERVICES_SGW_STACK_SUFFIX = "ServicesSGW"
  SERVICES_SGW_ELB_STACK_SUFFIX = "ServicesSGWELB"
  KERNEL_STACK_SUFFIX = "Kernel"
  KERNEL1_STACK_SUFFIX = "Kernel1"
  KERNEL2_STACK_SUFFIX = "Kernel2"
  KERNEL3_STACK_SUFFIX = "Kernel3"
  KERNEL4_STACK_SUFFIX = "Kernel4"
  REPLAYER_STACK_SUFFIX = "Replayer"
  PORTAL_ELB_STACK_SUFFIX = "PortalElb"
  PORTAL_STACK_SUFFIX = "Portal"
  LOGSTASH_ELB_STACK_SUFFIX = "LogstashELB"
  LOGSTASH_STACK_SUFFIX = "Logstash"
  PORTAL_GW_STACK_SUFFIX = "PortalGW"
  PORTAL_GW_ELB_STACK_SUFFIX = "PortalGWELB"
  BATCH_STACK_SUFFIX = "Batch"
  BASTION_STACK_SUFFIX = "Bastion"
  BASTION_EBS_STACK_SUFFIX = "BastionEbs"
  ALARMBATCH_STACK_SUFFIX = "AlarmBatch"
  ALARMRDS_STACK_SUFFIX = "AlarmRds"
  ALARMRDS_REPLICA_STACK_SUFFIX = "AlarmRdsReplica"
  ALARM_PORTAL_SUFFIX = "AlarmPortal"
  ALARM_SERVICES_SUFFIX = "AlarmServices"
  ALARM_SYSLOGNG_SUFFIX = "AlarmSyslogNg"
  ALARM_SNS_SUFFIX = "AlarmSns"
  ALARM_LINUX_SYSTEM_SUFFIX = "AlarmLinuxSystem"
  ALARM_KERNEL_CPU_SUFFIX = "AlarmKernelCPUUtil"
  ALARMKERNEL_STACK_SUFFIX = "AlarmKernel"
  ALARMKERNEL1_STACK_SUFFIX = "AlarmKernel1"
  ALARMKERNEL2_STACK_SUFFIX = "AlarmKernel2"
  ALARMKERNEL3_STACK_SUFFIX = "AlarmKernel3"
  ALARMKERNEL4_STACK_SUFFIX = "AlarmKernel4"
  ALARM_COMMON_ELB_STACK_SUFFIX = "AlarmCommonElb"
  ALARM_BASE_ELB_STACK_SUFFIX = "AlarmBaseElb"
  MIGRATION_STACK_SUFFIX = "Migration"
  MIGRATION_EBS_STACK_SUFFIX = "MigrationEbs"

  def initialize(stackParams)
    begin
      @cf = AWS::CloudFormation.new(
          :access_key_id => stackParams.accesskey,
          :secret_access_key => stackParams.secretkey,
          :region => stackParams.region)
      @stackParams = stackParams
    rescue Exception => error
      puts "KSCfUtil>>initialize: error " + e.message
      raise StandardError.new("KSCfUtil>>initialize: error  #{e.message}");
    end
  end

  def self.getStackname(stackParams, suffix, targetShard)
    if targetShard.nil?
      stackNm = "Keystone-2-" + stackParams.getEnvStripDr.upcase + "-" + stackParams.shard
    else
      stackNm = "Keystone-2-" + stackParams.getEnvStripDr.upcase + "-" + targetShard
    end

    unless suffix.nil?
      stackNm += "-" + suffix
    end

    unless  stackParams.instancenumber.nil?
      stackNm += stackParams.instancenumber
    end

    return stackNm
  end

  def showKeystoneStacks()
    stacks = @cf.stacks
    puts "\nKeystone stacks in region #{@stackParams.region}"
    stacks.each do |stack|
      if stack.name.start_with?('Keystone-2-')
        puts stack.name
      end
    end
  end

  def getStackResource(stack_name, logicalId, physicalId)
    if logicalId.nil?
      res = @cf.stack_resource(physicalId)
      return res.logical_resource_id
    else
      res = @cf.stacks[stack_name].resources[logicalId]
      begin
        phyId = res.physical_resource_id
      rescue
        #puts "Stack resource #{logicalId} not found"
        return nil
      end
    end
  end

  def getResourceStatus(stack_name, logicalId)
    stat = @cf.stacks[stack_name].resources[logicalId].resource_status
    return stat
  end

  def getResourceStatusReason(stack_name, logicalId)
    stat = @cf.stacks[stack_name].resources[logicalId].resource_status_reason
    return stat
  end

  def getStackOutput(stack_name, key)
    begin
      #puts "getStackOutput: called for #{stack_name} and #{key} @cf = #{@cf}"
      outputArray = @cf.stacks[stack_name].outputs
    rescue Exception => e
      #puts "getStackOutput: Processing error occured accessing #{stack_name} > #{key} - #{e.message}\n"
      return nil
    end
    #puts "outputArray = #{outputArray}"
    outputArray.each do |output|
      if output.key == key
        return output.value
      end
    end
    puts "Error getStackOutput: output not found for #{key} in stack #{stack_name}"
    return nil
  end

  def getStackInfo(name)
    stack = @cf.stacks[name]
    stack.creation_time
  end

  def showEnvKeystoneStacks()
    stacks = @cf.stacks
    sbuf = Array.new
    puts "\nKeystone stacks in env #{@stackParams.env} and region #{@stackParams.region} starting with Keystone-2-#{@stackParams.env.upcase}"
    stacks.each do |stack|
      if stack.name.start_with?("Keystone-2-#{@stackParams.env.upcase}")
        sbuf << stack.name
      end
    end
    sbuf
  end

  #
  # Return an array of all stack names containing the given substring, all case independent
  #
  def getKeystoneStacks(substring)
    stacks = @cf.stacks
    sbuf = Array.new
    stacks.each do |stack|
      if stack.name.downcase.include? substring.downcase
        sbuf << stack.name
      end
    end
    sbuf
  end

  def getTestStacks()
    ['']
  end

  def deleteStacks(stacklist, shard)
    @stackParams.shard = shard
    stackSuffixes = stacklist

    stackSuffixes.each do |suffix|
      stackname = getStackname(@stackParams, suffix, nil)
      deleteStack(stackname)
      waitForDeleteCompletion(stackname)
    end
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
  stackBuild.shard = 'NAGift'
  stackBuild.env = 'qa-m'
  stackBuild.profile = StackBuildParams::PROFILE_MEDIUM

  puts "Using #{stackBuild.to_s}"


  dep = KSCfUtil.new(stackBuild)
  #puts dep.showEnvKeystoneStacks
  #puts dep.getStackResource(KSCfUtil.getStackname(stackBuild, "Services",nil),"RestfulServicesAutoScalingGroup",nil)
  puts dep.getKeystoneStacks('keystone-2-')
end