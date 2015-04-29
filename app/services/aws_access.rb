#
# Title: AwsAccess
# Description: Interface to ks_aws_util amazon cloud utilities, all class methods.
#               ks_aws_util methods throw a StandardError on init error.
#
# Author: rholl00 
# Date: 12/11/14
#


require_relative 'aws_util/stack_build_params'
require_relative 'aws_util/ks_maint_util'
require_relative 'aws_util/ks_cf_util'
require_relative 'aws_util/ks_rds_util'

class AwsAccess
  # def initialize(stackParams)
  #   puts "CfController>>aws_setup called"
  #   @stackBuild = stackParams
  #   cf_util = KSCfUtil.new(@stackBuild)
  #   rds_util = KSRdsUtil.new(@stackBuild)
  #   maint_util = KSMaintUtil.new(@stackBuild)
  # end

  @@sshKeyPath = File.expand_path("../../keys/devKey.pem", File.dirname(__FILE__))

  def self.getEnvsStatus(envArray, stackParams)
    begin
      maint_util = KSMaintUtil.new(stackParams)
      maint_util.getEnvsStatus(envArray)
    rescue Exception => e
      puts "getEnvsStatus: error - #{e.message}"
      raise StandardError.new("AWS access error - " + e.message)
    end
  end

  def self.getDeployedEnvs(stackParams)
    maint_util = KSMaintUtil.new(stackParams)
    envs = maint_util.getDeployedEnvs
    deployedEnvs = []
    envs.each do |env|
      if maint_util.isEnvDeployed(env)
        deployedEnvs << env
      end
    end
    deployedEnvs
  end

  def self.stopEnv(stackParams)
    maint_util = KSMaintUtil.new(stackParams)
    maint_util.suspendEnv
  end

  def self.startEnv(stackParams)
    maint_util = KSMaintUtil.new(stackParams)
    maint_util.startEnv
  end


  def self.getGiftStatus(stackParams)
    puts "getGiftStatus: called for shard #{stackParams.shard}"
    maint_util = KSMaintUtil.new(stackParams)
    rds_util = KSRdsUtil.new(stackParams)

    gift_info = Hash.new
    #Add EC2 Info Hash of array of hashes
    gift_info[:ec2_info] = {}
    ec2sArray = maint_util.getAsgEc2Info("Services", KSCfUtil::SERVICES_STACK_SUFFIX, KSMaintUtil::SERVICES_ASG_LOGICAL_ID,@@sshKeyPath)
    ec2sArray.empty? ? gift_info[:ec2_info]["Services"] = [{'IPAddress' => 'Not Found'}] : gift_info[:ec2_info]["Services"] = ec2sArray
    ec2sArray = maint_util.getAsgEc2Info("Kernel1", KSCfUtil::KERNEL1_STACK_SUFFIX, KSMaintUtil::KERNEL1_ASG_LOGICAL_ID,@@sshKeyPath)
    ec2sArray.empty? ? gift_info[:ec2_info]["Kernel1"] = [{'IPAddress' => 'Not Found'}] : gift_info[:ec2_info]["Kernel1"] = ec2sArray
    ec2sArray = maint_util.getAsgEc2Info("Kernel2", KSCfUtil::KERNEL2_STACK_SUFFIX, KSMaintUtil::KERNEL2_ASG_LOGICAL_ID,@@sshKeyPath)
    ec2sArray.empty? ? gift_info[:ec2_info]["Kernel2"] = [{'IPAddress' => 'Not Found'}] : gift_info[:ec2_info]["Kernel2"] = ec2sArray
    ec2sArray = maint_util.getAsgEc2Info("Kernel3", KSCfUtil::KERNEL3_STACK_SUFFIX, KSMaintUtil::KERNEL3_ASG_LOGICAL_ID,@@sshKeyPath)
    ec2sArray.empty? ? gift_info[:ec2_info]["Kernel3"] = [{'IPAddress' => 'Not Found'}] : gift_info[:ec2_info]["Kernel3"] = ec2sArray
    ec2sArray = maint_util.getAsgEc2Info("Kernel4", KSCfUtil::KERNEL4_STACK_SUFFIX, KSMaintUtil::KERNEL4_ASG_LOGICAL_ID,@@sshKeyPath)
    ec2sArray.empty? ? gift_info[:ec2_info]["Kernel4"] = [{'IPAddress' => 'Not Found'}] : gift_info[:ec2_info]["Kernel4"] = ec2sArray
    ec2sArray = maint_util.getAsgEc2Info("Batch", KSCfUtil::BATCH_STACK_SUFFIX, KSMaintUtil::BATCH_ASG_LOGICAL_ID,@@sshKeyPath)
    ec2sArray.empty? ? gift_info[:ec2_info]["Batch"] = [{'IPAddress' => 'Not Found'}] : gift_info[:ec2_info]["Batch"] = ec2sArray
    ec2sArray = maint_util.getEc2Info("Bastion", KSCfUtil::BASTION_STACK_SUFFIX, KSMaintUtil::BASTION_LOGICAL_ID,@@sshKeyPath)
    ec2sArray.empty? ? gift_info[:ec2_info]["Bastion"] = [{'IPAddress' => 'Not Found'}] : gift_info[:ec2_info]["Bastion"] = ec2sArray

    gift_info[:s3_bucket_name] = maint_util.getS3BucketName

    rdsInstId = rds_util.getRdsInstanceId(stackParams)
    rdsInfoHash = rds_util.getRdsInfo(rdsInstId)
    unless rdsInfoHash.empty?
      addDbAccessInfo(rdsInfoHash, stackParams.shard, rdsInfoHash['Endpoint'])
    end
    gift_info[:rds_info] = rdsInfoHash
    rdsRepInstId = rds_util.getRdsReplicaInstanceId(stackParams)
    rdsRepInfoHash = rds_util.getRdsInfo(rdsRepInstId)
    unless rdsRepInfoHash.empty?
      addDbAccessInfo(rdsRepInfoHash, stackParams.shard, rdsRepInfoHash['Endpoint'])
    end
    gift_info[:rds_rep_info] = rdsRepInfoHash
    gift_info
  end

  def self.getCommonStatus(stackParams)
    puts "getCommonStatus: called for shard #{stackParams.shard}"
    rds_util = KSRdsUtil.new(stackParams)
    cf_util = KSCfUtil.new(stackParams)
    maint_util = KSMaintUtil.new(stackParams)
    common_info = Hash.new
    logRdsId = rds_util.getRdsLogInstanceId(stackParams)
    rds_info = rds_util.getRdsInfo(logRdsId)
    #puts "showEnvStatus: rds_info - #{rds_info}"
    @portalGwElbUrlHttp = cf_util.getStackOutput(KSCfUtil.getStackname(stackParams, KSCfUtil::PORTAL_GW_ELB_STACK_SUFFIX, nil), KSMaintUtil::PORTAL_GW_ELB_URL_OUTPUT_KEY)
    @portalElbUrlHttp = cf_util.getStackOutput(KSCfUtil.getStackname(stackParams, KSCfUtil::PORTAL_ELB_STACK_SUFFIX, nil), KSMaintUtil::PORTAL_ELB_URL_OUTPUT_KEY)
    @servicesGwElbUrlHttp = cf_util.getStackOutput(KSCfUtil.getStackname(stackParams, KSCfUtil::SERVICES_SGW_ELB_STACK_SUFFIX, nil), KSMaintUtil::SERVICES_GW_ELB_URL_OUTPUT_KEY)
    @logstashElbUrlHttp = cf_util.getStackOutput(KSCfUtil.getStackname(stackParams, KSCfUtil::LOGSTASH_ELB_STACK_SUFFIX, nil), KSMaintUtil::LOGSTASH_ELB_URL_OUTPUT_KEY)

    common_info[:rds_info] = rds_info
    common_info[:portalGwElbUrlHttp] = @portalGwElbUrlHttp
    common_info[:portalElbUrlHttp] = @portalElbUrlHttp
    common_info[:servicesGwElbUrlHttp] = @servicesGwElbUrlHttp
    common_info[:logstashElbUrlHttp] = @logstashElbUrlHttp

    #Add EC2 Info Hash of array of hashes
    common_info[:ec2_info] = {}

    ec2sArray = maint_util.getAsgEc2Info("Portal Gateway ", KSCfUtil::PORTAL_GW_STACK_SUFFIX, KSMaintUtil::PORTAL_GW_ASG_LOGICAL_ID,@@sshKeyPath)
    common_info[:ec2_info]["Portal Gateway"] = ec2sArray

    ec2sArray = maint_util.getAsgEc2Info("Portal         ", KSCfUtil::PORTAL_STACK_SUFFIX, KSMaintUtil::PORTAL_ASG_LOGICAL_ID,@@sshKeyPath)
    common_info[:ec2_info]["Portal"] = ec2sArray

    ec2sArray = maint_util.getAsgEc2Info("Logstash       ", KSCfUtil::LOGSTASH_STACK_SUFFIX, KSMaintUtil::LOGSTASH_ASG_LOGICAL_ID,@@sshKeyPath)
    common_info[:ec2_info]["Logstash"] = ec2sArray

    ec2sArray = maint_util.getAsgEc2Info("Services SGW   ", KSCfUtil::SERVICES_SGW_STACK_SUFFIX, KSMaintUtil::SERVICES_SGW_ASG_LOGICAL_ID,@@sshKeyPath)
    common_info[:ec2_info]["Services SGW"] = ec2sArray
    common_info
  end

  def self.getStackBuild(env, region, shard)
    stackBuild = StackBuildParams.new
    stackBuild.modparam = nil
    stackBuild.stacks= ['1']
    stackBuild.accesskey = ENV['AWS_ACCESS_KEY']
    stackBuild.region = region
    stackBuild.secretkey = ENV['AWS_SECRET_KEY']
    stackBuild.shard = shard
    stackBuild.env = env.downcase unless env.nil?
    stackBuild
  end

  private

  def self.addDbAccessInfo(rdsInfoHash, shard, endpoint)
    rdsInfoHash['Database Access:'] = ''
    rdsInfoHash['Export'] = "export MYSQL_PWD=#{KSMaintUtil::DB_USER_NAME}_#{shard.downcase}"
    rdsInfoHash['MySql Client'] = "mysql --host=#{endpoint} --port=3306 --user=#{KSMaintUtil::DB_USER_NAME} --database=keystone_db"
    rdsInfoHash['Admin Addess'] = "keystone_admin/kys_admin_#{shard.downcase}"
  end

end