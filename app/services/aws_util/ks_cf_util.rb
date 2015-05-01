require 'aws-sdk'

require_relative './stack_build_params.rb'
require_relative 'ks_common'


class KSCfUtil

  include KSCommon

  PRE_FAILOVER_SUFFIXS = [ROLES_STACK_SUFFIX,
                          S3_STACK_SUFFIX,
                          DB_PARAMETERS_STACK_SUFFIX,
                          REPLICA_DB_PARAMETERS_STACK_SUFFIX,
                          SECGRP_STACK_SUFFIX,
                          ENI_STACK_SUFFIX]

  PRE_FAILOVER_COMMON_SUFFIXS = [LOG_DB_STACK_SUFFIX,
                                 LOG_DB_TRANSIENT_STACK_SUFFIX,
                                 PORTAL_GW_ELB_STACK_SUFFIX,
                                 SERVICES_SGW_ELB_STACK_SUFFIX]

  ON_FAILOVER_SUFFIXS = [MIGRATION_EBS_STACK_SUFFIX,
                         MIGRATION_STACK_SUFFIX,
                         ALARMBATCH_STACK_SUFFIX,
                         ALARMRDS_STACK_SUFFIX,
                         ALARMRDS_REPLICA_STACK_SUFFIX,
                         ALARMKERNEL1_STACK_SUFFIX,
                         ALARMKERNEL2_STACK_SUFFIX,
                         ALARMKERNEL3_STACK_SUFFIX,
                         ALARMKERNEL4_STACK_SUFFIX,
                         ALARM_BASE_ELB_STACK_SUFFIX,
                         BASTION_STACK_SUFFIX,
                         BATCH_STACK_SUFFIX,
                         KERNEL1_STACK_SUFFIX,
                         KERNEL2_STACK_SUFFIX,
                         KERNEL3_STACK_SUFFIX,
                         KERNEL4_STACK_SUFFIX,
                         SERVICES_STACK_SUFFIX,

                         DB_STACK_SUFFIX,
                         REPLICA_DB_STACK_SUFFIX,
                         TRANSIENT_STACK_SUFFIX,
                         BASTION_EBS_STACK_SUFFIX
  ]

  ON_FAILOVER_COMMON_SUFFIXS = [PORTAL_STACK_SUFFIX,
                                PORTAL_ELB_STACK_SUFFIX,
                                PORTAL_GW_STACK_SUFFIX,
                                ALARM_COMMON_ELB_STACK_SUFFIX,
                                SERVICES_SGW_STACK_SUFFIX,
                                LOGSTASH_STACK_SUFFIX,
                                LOGSTASH_ELB_STACK_SUFFIX
  ]

  def initialize(stackParams)
    @stackParams = stackParams
    begin
      @cf = Aws::CloudFormation::Client.new(
          :access_key_id => stackParams.accesskey,
          :secret_access_key => stackParams.secretkey,
          :region => stackParams.region)

      @cfalt = Aws::CloudFormation::Client.new(
          :access_key_id => stackParams.accesskey,
          :secret_access_key => stackParams.secretkey,
          :region => stackParams.alternateregion)
    rescue Exception => e
      puts "KSCfUtil>>initialize: error " + e.message
      exit
    end
  end

  def getAllKeystoneStacks()
    resp = @cf.describe_stacks
    stacks = resp.data[:stacks]
    next_token = resp.data[:next_token]

    until next_token.nil?
      #puts "getAllKeystoneStacks: next_token = #{next_token} stack count #{stacks.size}"
      resp = @cf.describe_stacks(next_token: next_token)
      (stacks << resp.data[:stacks]).flatten!
      next_token = resp.data[:next_token]
    end
    keystone_stacks = []
    stacks.each do |stack|
      if stack[:stack_name].start_with?('Keystone-2-')
        keystone_stacks << stack[:stack_name]
      end
    end
    keystone_stacks
  end

  def showKeystoneStacks()
    stacknames = getAllKeystoneStacks()
    puts "\n#{stacknames.size} Keystone stacks in region #{@stackParams.region}"
    stacknames.each do |stack|
      puts stack
    end
  end

  #
  # Return an array of all stack names containing the given substring, all case independent
  #
  def getKeystoneStacks(substring)
    stacknames = getAllKeystoneStacks()
    sbuf = Array.new
    stacknames.each do |stack|
      if stack.downcase.include? substring.downcase
        sbuf << stack
      end
    end
    sbuf
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

  def deleteStack(stack_name)
    puts "\nDeleting stack #{stack_name}"
    @cf.delete_stack(stack_name: stack_name)
  end

  def getStackOutput(stack_name, key)
    begin
      resp = @cf.describe_stacks(
          stack_name: stack_name
      )
      outputArray = resp.data[:stacks][0][:outputs]
    rescue Exception => e
      #puts "getStackOutput: Processing error occured accessing #{stack_name} > #{key} - #{e.message}\n"
      return nil
    end
    outputArray.each do |output|
      if output.output_key == key
        return output.output_value
      end
    end
    puts "Error getStackOutput: output not found for #{key} in stack #{stack_name}"
    return nil
  end

  def getStackStatus(stackName)
    begin
      resp = @cf.describe_stacks(stack_name: stackName)
    rescue Exception => e
      if e.message.include?("does not exist")
        return false
      else
        puts "getStackStatus error - " + e.message
        return false
      end
    end
    return resp.data[:stacks][0].stack_status
  end

  def getStackStatusReason(stackName)
    begin
      resp = @cf.describe_stacks(stack_name: stackName)
    rescue Exception => e
      if e.message.include?("does not exist")
        return 'unknown'
      else
        puts "getStackStatusReason error - " + e.message
        return 'unknown'
      end
    end
    return resp.data[:stacks][0].stack_status_reason
  end

  def stackExists(stackName)
    begin
      resp = @cf.describe_stacks(stack_name: stackName)
    rescue Exception => e
      if e.message.include?("does not exist")
        return false
      else
        puts "stackExists error - " + e.message
        #puts e.backtrace
        return false
      end
    end
    return resp.data[:stacks].size > 0
  end

  def stackExistsInAlternateRegion(stackName)
    begin
      resp = @cfalt.describe_stacks(stack_name: stackName)
    rescue Exception => e
      if e.message.include?("does not exist")
        return false
      else
        puts "stackExists error - " + e.message
        return false
      end
    end
    return resp.data[:stacks].size > 0
  end

  #
  #Return a physical or logical resounce id for a stack
  #
  def getStackResource(stack_name, logicalId, physicalId)
    options = {}
    options[:stack_name] = stack_name
    unless logicalId.nil?
      options[:logical_resource_id] = logicalId
    end
    unless physicalId.nil?
      options[:physical_resource_id] = physicalId
    end

    begin
      res = @cf.describe_stack_resources(options)
      unless logicalId.nil?
        return res.data[:stack_resources][0][:physical_resource_id]
      end
      unless physicalId.nil?
        return res.data[:stack_resources][0][:logical_resource_id]
      end
    rescue
      #puts "getStackResource: resource not found for stack: #{stack_name} logicalId: #{logicalId} physicalId: #{physicalId}"
      return nil
    end
    return nil
  end

  def getStackResourceFromAlternateRegion(stack_name, logicalId, physicalId)
    options = {}
    options[:stack_name] = stack_name
    unless logicalId.nil?
      options[:logical_resource_id] = logicalId
    end
    unless physicalId.nil?
      options[:physical_resource_id] = physicalId
    end

    begin
      res = @cfalt.describe_stack_resources(options)
      unless logicalId.nil?
        return res.data[:stack_resources][0][:physical_resource_id]
      end
      unless physicalId.nil?
        return res.data[:stack_resources][0][:logical_resource_id]
      end
    rescue
      #puts "getStackResource: resource not found for stack: #{stack_name} logicalId: #{logicalId} physicalId: #{physicalId}"
      return nil
    end
    return nil
  end

  #
  #Return all resounces for a stack
  #
  def getStackResources(stack_name)
    options = {}
    options[:stack_name] = stack_name

    begin
      res = @cf.describe_stack_resources(options)
    rescue
      #puts "getStackResource: resource not found for stack #{stack_name}"
      return nil
    end
    return res.data[:stack_resources][0]
  end


  def getResourceStatus(stack_name, logicalId)
    options = {}
    options[:stack_name] = stack_name
    options[:logical_resource_id] = logicalId
    res = @cf.describe_stack_resources(options)
    return res.data[:stack_resources][0][:resource_status]
  end

  def getResourceStatusReason(stack_name, logicalId)
    options = {}
    options[:stack_name] = stack_name
    options[:logical_resource_id] = logicalId
    res = @cf.describe_stack_resources(options)
    return res.data[:stack_resources][0][:resource_status_reason]
  end

  def getStackOutputFromAlternateRegion(stack_name, key)
    begin
      resp = @cfalt.describe_stacks(
          stack_name: stack_name
      )
      outputArray = resp.data[:stacks][0][:outputs]
    rescue Exception => e
      puts "getStackOutputFromAlternateRegion: Processing error occured accessing #{stack_name} > #{key} - #{e.message}\n"
      return nil
    end
    outputArray.each do |output|
      if output.output_key == key
        return output.output_value
      end
    end
    puts "Error getSgetStackOutputFromAlternateRegiontackOutput: output not found for #{key} in stack #{stack_name}"
    return nil
  end

  def getStackOuputParams(stackParams, stackSuffix, targetShard, key)
    return getStackOutput(getStackname(stackParams, stackSuffix, targetShard), key)
  end

  def getStackOuputParamsAlternateRegion(stackParams, stackSuffix, targetShard, key)
    return getStackOutputFromAlternateRegion(getStackname(stackParams, stackSuffix, targetShard), key)
  end
end

if __FILE__==$0
  stackBuild = StackBuildParams.new
  stackBuild.modparam = nil
  stackBuild.stacks= ['1']
  stackBuild.accesskey = ENV['AWS_ACCESS_KEY']
  stackBuild.alternateregion = 'us-east-1'
  stackBuild.region = 'us-west-2'
  stackBuild.secretkey = ENV['AWS_SECRET_KEY']
  stackBuild.shard = 'NAGift'
  stackBuild.env = 'dev'
  stackBuild.profile = KSCommon::PROFILE_MEDIUM

  puts "Using #{stackBuild.to_s}"


  dep = KSCfUtil.new(stackBuild)
  dep.showKeystoneStacks

  # stackname = 'Keystone-2-PP-DR-NAGift-ReplicaDBParameters'
  #
  # puts "\nDeleting #{stackname}"
  # dep.deleteStack(stackname)

  #dep.deleteStacks(KSCfUtil::PRE_FAILOVER_COMMON_SUFFIXS, 'Common')
  #dep.deleteStacks(KSCfUtil::PRE_FAILOVER_SUFFIXS, 'NAGift')
  #dep.deleteStacks(KSCfUtil::PRE_FAILOVER_SUFFIXS, 'IGift')
end