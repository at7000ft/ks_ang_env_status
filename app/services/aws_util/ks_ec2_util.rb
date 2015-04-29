require 'aws-sdk'

require_relative './stack_build_params.rb'


class KSEc2Util

  EC2_STATUS_RUNNING = 'running'
  EC2_STATUS_STOPPED = 'stopped'
  TIMEOUT_COUNT = 30
  WAIT_SUCCESS = 'success'
  WAIT_TIMEOUT = 'timeout'

  def initialize(stackParams)
    @stackParams = stackParams
    #Run the local config.rb script to load AWS props and config AWS with keys and region
    begin
      @ec2 = AWS::EC2.new(
          :access_key_id => @stackParams.accesskey,
          :secret_access_key => @stackParams.secretkey,
          :region => @stackParams.region)
    rescue Exception => e
      puts "KSEc2Util>>initialize: error " + e.message
      raise StandardError.new("KSEc2Util>>initialize: error  #{e.message}");
    end
  end

  def deleteSecurityGroup(scname)
    puts "Deleting Security Group #{scname}"
    secgrp = @ec2.security_groups.create(scname)
    if secgrp.exists?
      puts "Security Group #{scname} found"
    else
      puts "Security Group #{scname} not found"
      return
    end
    secgrp.delete
    if secgrp.exists?
      puts "Security Group #{scname} could not be deleted"
    else
      puts "Security Group #{scname} deleted"
      return
    end
  end

  def terminateInstances(ids)
    puts "Terminating EC2 instances #{ids}"
    begin
      options = Hash.new
      options[:instance_ids] = ids
      @ec2.client.terminate_instances(options)
    rescue Exception => e
      puts "KSEc2Util>>terminateInstances: error " + e.message
    end
  end

  def stopInstances(ids)
    puts "Stopping EC2 instances #{ids}"
    begin
      options = Hash.new
      options[:instance_ids] = ids
      @ec2.client.stop_instances(options)
    rescue Exception => e
      puts "KSEc2Util>>stopInstances: error " + e.message
    end
  end

  def startInstances(ids)
    puts "Starting EC2 instances #{ids}"
    begin
      options = Hash.new
      options[:instance_ids] = ids
      @ec2.client.start_instances(options)
    rescue Exception => e
      puts "KSEc2Util>>startInstances: error " + e.message
    end
  end

  def waitForInstanceRunning(instId)
    stat = getInstanceStatus(instId)
    puts "Waiting for #{instId} running status - #{stat}"
    count = 0
    until stat == EC2_STATUS_RUNNING do
      stat = getInstanceStatus(instId)
      sleep(4)
      puts "Waiting for #{instId} running status - #{stat}"
      count += 1
      if count > TIMEOUT_COUNT
        puts "Timed out waiting for instance to leave running state"
        return WAIT_TIMEOUT
      end
    end
    return WAIT_SUCCESS
  end

  def waitForInstanceNotRunning(instId)
    stat = getInstanceStatus(instId)
    puts "Waiting for #{instId} to leave running status - #{stat}"
    count = 0
    while stat == EC2_STATUS_RUNNING do
      stat = getInstanceStatus(instId)
      sleep(4)
      puts "Waiting for #{instId} to leave running status - #{stat}"
      count += 1
      if count > TIMEOUT_COUNT
        puts "Timed out waiting for instance to enter running state"
        return WAIT_TIMEOUT
      end
    end
    return WAIT_SUCCESS
  end

  def getInstanceStatus(id)
    #puts "Getting EC2 instance status #{id}"
    begin
      options = Hash.new
      options[:instance_ids] = [id]
      resp = @ec2.client.describe_instance_status(options)
    rescue Exception => e
      puts "KSEc2Util>>startInstances: error " + e.message
      return nil
    end
    arr = resp.data[:instance_status_set][0]
    if arr.nil?
      return nil
    else
      return arr[:instance_state][:name]
    end
  end

  #
  # Return info Hash on an EC2 instance including:
  #   - PrivateDns
  #   - AmiId
  #   - InstanceType
  #   - AvailabilityZone
  #   - InstanceId
  #   - State
  #
  def getInstanceData(id)
    #puts "Getting EC2 instance data #{id}"
    info = Hash.new
    begin
      options = Hash.new
      options[:instance_ids] = [id]
      resp = @ec2.client.describe_instances(options)

      infoHash2 = resp.data[:reservation_set][0][:instances_set][0]
    rescue Exception => e
      #puts "KSEc2Util>>getInstanceData: error " + e.message
      return nil
    end
    if infoHash2.nil?
      return nil
    else
      info['IPAddress'] = infoHash2[:network_interface_set][0][:private_ip_address]
      if infoHash2[:network_interface_set].size() == 2
        info['IPAddress(2)'] =  infoHash2[:network_interface_set][1][:private_ip_address]
      end
      info['AmiId'] = infoHash2[:image_id]
      info['InstanceType'] = infoHash2[:instance_type]
      info['AvailablityZone'] = infoHash2[:placement][:availability_zone]
    end

    begin
      options = Hash.new
      options[:instance_ids] = [id]
      resp = @ec2.client.describe_instance_status(options)
    rescue Exception => e
      puts "KSEc2Util>>getInstanceData: error " + e.message
      return nil
    end
    infoHash = resp.data[:instance_status_set][0]
    if infoHash.nil?
      return nil
    else
      info['InstanceId'] = infoHash[:instance_id]
      info['State'] = infoHash[:instance_state][:name]
    end
    return info
  end

  def getVpc()
    vpcs = @ec2.vpcs
    vpcs.each do |vpc|
      puts "VPCs - #{vpc.vpc_id}"
    end
    return vpcs[0]
  end


end


if __FILE__==$0

  #
  #Show stopped instances
  # aws ec2 describe-instances --filters "Name=instance-state-name, Values=stopped"
  #
  #Stop an instance
  #aws ec2 stop-instances --instance-ids i-1a2b3c4d
  #
  #Get instance status
  # aws ec2 describe-instances --filters "Name=instance-id, Values=i-bb1000b6"
  # aws ec2 describe-instances --instance-ids i-5203422c
  # aws ec2 describe-instances --filters "Name=instance-type,Values=m1.small,m1.medium" "Name=availability-zone,Values=us-west-2c"

  KSDeploy.setTemplatePath(KSDeploy::TEMPLATE_PATH)
  KSDeploy.setPropertiesPath(KSDeploy::PROPERTIES_PATH)

  stackBuild = StackBuildParams.new
  stackBuild.modparam = nil
  stackBuild.stacks= ['1']
  stackBuild.accesskey = ENV['AWS_ACCESS_KEY']
  stackBuild.region = 'us-west-2'
  stackBuild.secretkey = ENV['AWS_SECRET_KEY']
  stackBuild.shard = 'NAGift'
  stackBuild.env = 'dev'
  stackBuild.profile = KSDeployProperties::PROFILE_MEDIUM

  util = KSEc2Util.new(stackBuild)

  stackSuffix = KSDeploy::BASTION_STACK_SUFFIX
  bastionLogicalId = 'BastionHost'

  # bastionInstId = util.getStackResource(KSCfUtil.getStackname(stackBuild, stackSuffix, nil), bastionLogicalId, nil)
  # if bastionInstId.nil?
  #   puts "Id not found in stack @{stackSuffix} with logical id #{bastionLogicalId}"
  # end
  #inst.deleteSecurityGroup("TestSG")
  #inst.getVpc

  ids = [bastionInstId]
  #util.stopInstances(ids)
  infoHash = util.getInstanceData('i-3086743a')
  puts "EC2 Instance Info:"
  infoHash.each do |key, value|
    puts "#{key}: #{value}"
  end

  #puts "Status - #{stat}"
  #util.startInstances(ids)
end