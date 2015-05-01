require 'aws-sdk'

require_relative './stack_build_params.rb'
require_relative 'ks_common'

class KSEc2Util

  include KSCommon

  EC2_STATUS_RUNNING = 'running'
  EC2_STATUS_STOPPED = 'stopped'
  TIMEOUT_COUNT = 30
  WAIT_SUCCESS = 'success'
  WAIT_TIMEOUT = 'timeout'

  def initialize(stackParams)
    @stackParams = stackParams
    #Run the local config.rb script to load AWS props and config AWS with keys and region
    begin
      @ec2 = Aws::EC2::Client.new(
          :access_key_id => @stackParams.accesskey,
          :secret_access_key => @stackParams.secretkey,
          :region => @stackParams.region)
    rescue Exception => e
      puts "KSEc2Util>>initialize: error " + e.message
    end
  end

  def addIngressRule(securityGroupID, port, protocol, targetSecGrpId)
    permissions = [
        {
            ip_protocol: protocol,
            from_port: port,
            to_port: port,
            user_id_group_pairs: [
                {
                    group_id: securityGroupID,
                },
            ],
        },
    ]
    resp = @ec2.authorize_security_group_ingress(group_id: targetSecGrpId, ip_permissions: permissions)
  end

  def addEgressRule(securityGroupID, port, protocol, targetSecGrpId)
    permissions = [
        {
            ip_protocol: protocol,
            from_port: port,
            to_port: port,
            user_id_group_pairs: [
                {
                    group_id: securityGroupID,
                },
            ],
        },
    ]
    resp = @ec2.authorize_security_group_egress(group_id: targetSecGrpId, ip_permissions: permissions)
  end

  def revokeEgressRule(securityGroupID, permissions)
    @ec2.revoke_security_group_egress(group_id: securityGroupID, ip_permissions: permissions)
  end

  def revokeIngressRule(securityGroupID, permissions)
    @ec2.revoke_security_group_ingress(group_id: securityGroupID, ip_permissions: permissions)
  end

  #
  # First check for the existance of an AWS keypair of name name, if not found create a new keypair
  # and write new key contents to KEYS_FOLDER as name.pem.
  #
  def createAndSaveKeyPair(name, keyFilePath)
    raise "createAndSaveKeyPair:  key name is nil" if name.nil?
    #See if key exists in aws
    begin
      options = {:key_names => [name]}
      resp = @ec2.describe_key_pairs(options)
      if resp.data[:key_pairs].size >= 1
        puts "createAndSaveKeyPair: keypair #{name} already exists, not creating new key"
        return
      end
    rescue Exception => e
      #No problem, key not found
    end

    #Keypair does not exist in AWS, create one
    options = {:key_name => name, :dry_run => false}
    #resp = @ec2.client.delete_key_pair(options)
    resp = @ec2.create_key_pair(options)
    #puts "createAndSaveKeyPair: resp data - #{resp.data}"
    privKeyString = resp.key_material
    #
    Dir.mkdir(KEYS_FOLDER) unless File.exists?(KEYS_FOLDER)
    keyFilePath = KEYS_FOLDER + '/' + name + '.pem'
    puts "createAndSaveKeyPair: creating new key, private key saved to #{File.absolute_path(keyFilePath)}"
    if File.exists?(keyFilePath)
      File.delete(keyFilePath)
    end
    f = File.open(keyFilePath, 'w')
    f.puts privKeyString
    f.close
  end

  def securityGroupName(secGroupId)
    begin
      resp = @ec2.describe_security_groups(group_ids: [secGroupId])
      return resp.data.security_groups[0][:group_name]
    rescue Exception => e
      puts "securityGroupName: Error - #{e.message}"
    end
  end

  def enisForSecurityGroup(group_name)
    resp = @ec2.describe_network_interfaces(filters: [{name: 'group-name', values: [group_name]}])
    enis = resp.data.network_interfaces
    eni_ids = []
    enis.each do |eni|
      eni_ids << eni[:network_interface_id]
    end
    return eni_ids
  end

  #
  #First check for EC2 instances using this ENI and terminate them, then delete the eni
  #
  def delete_eni(eni_id)
    begin
      ec2s = ec2_instances_using_eni(eni_id)
      unless ec2s.empty?
        @ec2.terminate_instances(instance_ids: ec2s)
        sleep(5)
      end
      detach_network_interface(eni_id)
      @ec2.delete_network_interface(network_interface_id: eni_id)

    rescue Exception => e
      puts "delete_eni: Error - #{e.message}"
    end
  end

  def ec2_instances_using_eni(eni_id)
    begin
      resp = @ec2.describe_instances(filters: [{name: 'network-interface.network-interface-id', values: [eni_id]}])
      ec2_ids = []
      resp.data.reservations.each do |res|
        res[:instances].each do |inst|
          inst[:network_interfaces].each do |netif|
            ec2_ids << inst[:instance_id]
          end
        end
      end

    rescue Exception => e
      puts "ec2_instances_using_eni: Error - #{e.message}"
    end
    return ec2_ids
  end

  def detach_network_interface(eni_id)
    begin
      resp = @ec2.describe_network_interfaces(network_interface_ids: [eni_id])
      enis = resp.data.network_interfaces
      attachment_ids = []
      enis.each do |eni|
        attachment_ids << eni[:attachment][:attachment_id]
      end
      attachment_ids.each do |attachment_id|
        resp = @ec2.detach_network_interface(attachment_id: attachment_id)
      end
    rescue Exception => e
      puts "detach_network_interface: Error - #{e.message}"
    end
  end

  def deleteSecurityGroup(secGroupId)
    begin
      @ec2.delete_security_group(group_id: secGroupId)
    rescue Exception => e
      puts "deleteSecurityGroup: Error - #{e.message}"
    end
  end

  def deleteSecurityGroupRules(secGroupId)
    begin
      resp = @ec2.describe_security_groups(group_ids: [secGroupId])
      inboundRules = resp.data[:security_groups][0][:ip_permissions]
      outboundRules = resp.data[:security_groups][0][:ip_permissions_egress]
      unless inboundRules.empty?
        permissions = []
        inboundRules.each do |rule|
          permissions << permissionHashFromRule(rule)
        end
        revokeIngressRule(secGroupId, permissions)
      end
      unless outboundRules.empty?
        permissions = []
        outboundRules.each do |rule|
          permissions << permissionHashFromRule(rule)
        end
        revokeEgressRule(secGroupId, permissions)
      end
    rescue Exception => e
      puts "deleteSecurityGroupRules: Error - #{e.message}"
    end
  end

  def permissionHashFromRule(rule)
    permHash = {}
    permHash[:ip_protocol] = rule[:ip_protocol]
    permHash[:from_port] = rule[:from_port]
    permHash[:to_port] = rule[:to_port]
    if rule[:user_id_group_pairs].nil? || rule[:user_id_group_pairs].empty?
      rangeArr = []
      rule[:ip_ranges].each do |cidr|
        rangeArr << {cidr_ip: cidr[:cidr_ip]}
      end
      permHash[:ip_ranges] = rangeArr
    else
      idGroupArr = []
      rule[:user_id_group_pairs].each do |ids|
        idGroupArr << {group_id: ids[:group_id]}
      end
      permHash[:user_id_group_pairs] = idGroupArr
    end
    return permHash
  end

  def securityGroupsFor(env)
    groupIds = []
    secgrpColl = @ec2.security_groups
    secgrpColl.filter('group-name', 'Keystone-2-DEV-*').each do |group|
      puts "SecGrp id - #{group.security_group_id} name - #{group.name}"
      groupIds << group.security_group_id
    end
    groupIds
  end

  def terminateInstances(ids)
    puts "Terminating EC2 instances #{ids}"
    begin
      options = Hash.new
      options[:instance_ids] = ids
      @ec2.terminate_instances(options)
    rescue Exception => e
      puts "KSEc2Util>>terminateInstances: error " + e.message
    end
  end

  def stopInstances(ids)
    puts "Stopping EC2 instances #{ids}"
    begin
      options = Hash.new
      options[:instance_ids] = ids
      @ec2.stop_instances(options)
    rescue Exception => e
      puts "KSEc2Util>>stopInstances: error " + e.message
    end
  end

  def startInstances(ids)
    puts "Starting EC2 instances #{ids}"
    begin
      options = Hash.new
      options[:instance_ids] = ids
      @ec2.start_instances(options)
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
      resp = @ec2.describe_instance_status(options)
    rescue Exception => e
      puts "KSEc2Util>>startInstances: error " + e.message
      return nil
    end
    arr = resp.data[:instance_statuses][0]
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
      resp = @ec2.describe_instances(options)

      infoHash2 = resp.data[:reservations][0][:instances][0]
    rescue Exception => e
      #puts "KSEc2Util>>getInstanceData: error " + e.message
      return nil
    end
    #Test for a terminated instance
    if infoHash2.nil? || infoHash2[:network_interfaces].empty?
      return nil
    else
      info['IPAddress'] = infoHash2[:network_interfaces][0][:private_ip_address]
      if infoHash2[:network_interfaces].size() == 2
        info['IPAddress(2)'] = infoHash2[:network_interfaces][1][:private_ip_address]
      end
      info['AmiId'] = infoHash2[:image_id]
      info['InstanceType'] = infoHash2[:instance_type]
      info['AvailablityZone'] = infoHash2[:placement][:availability_zone]
    end

    begin
      options = Hash.new
      options[:instance_ids] = [id]
      resp = @ec2.describe_instance_status(options)
    rescue Exception => e
      puts "KSEc2Util>>getInstanceData: error " + e.message
      return nil
    end
    infoHash = resp.data[:instance_statuses][0]
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

  # stackSuffix = KSDeploy::BASTION_STACK_SUFFIX
  # bastionLogicalId = 'BastionHost'
  #
  # bastionInstId = util.getStackResource(util.getStackname(stackBuild, stackSuffix, nil), bastionLogicalId, nil)
  # if bastionInstId.nil?
  #   puts "Id not found in stack @{stackSuffix} with logical id #{bastionLogicalId}"
  # end

  sgGroupId = "Keystone-2-DEV-Common-LogDB-KeystoneRDSSecurityGroup-15TBV90NRHOUZ"
  util.deleteSecurityGroup(sgGroupId)
  #util.getVpc

  #ids = [bastionInstId]
  #util.stopInstances(ids)
  # infoHash = util.getInstanceData('i-3086743a')
  # puts "EC2 Instance Info:"
  # infoHash.each do |key, value|
  #   puts "#{key}: #{value}"
  # end

  #puts "Status - #{stat}"
  #util.startInstances(ids)
end