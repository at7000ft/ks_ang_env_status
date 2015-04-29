require 'aws-sdk'

require_relative './stack_build_params.rb'


class KSRdsUtil

  ACCOUNT_ID_MAP = {'nonprod' => '593917551679', 'pp' => '524670336862', 'prod' => '???' }

  RDS_MODIFYING_STATUS = 'modifying'
  RDS_AVAILABLE_STATUS = 'available'
  RDS_REBOOTING_STATUS = 'rebooting'
  RDS_BACKING_UP_STATUS = 'backing-up'
  RDS_RENAMING_STATUS = 'renaming'




  def initialize(stackParams)
    @stackParams = stackParams
    #Run the local config.rb script to load AWS props and config AWS with keys and region
    begin
      @rds = AWS::RDS.new(
          :access_key_id => @stackParams.accesskey,
          :secret_access_key => @stackParams.secretkey,
          :region => @stackParams.region)

    rescue Exception => e
      puts "KSRdsUtil>>initialize: error " + e.message
      raise StandardError.new("KSRdsUtil>>initialize: error  #{e.message}");
    end
  end

  def describeRdsInstances()
    resp = @rds.client.describe_db_instances()
    resp.data[:db_instances].each do |inst|
      puts "DB instance #{inst[:db_instance_identifier]}"
    end
  end

  def getRdsStatus(dbInstId)
    resp = @rds.client.describe_db_instances()
    resp.data[:db_instances].each do |inst|
      if inst[:db_instance_identifier] == dbInstId
        return inst[:db_instance_status]
      end
    end
    return nil
  end

  def getRdsEndpoint(dbInstId)
    #puts "Getting RDS endpoint for #{dbInstId}"
    resp = @rds.client.describe_db_instances()
    resp.data[:db_instances].each do |inst|
      if inst[:db_instance_identifier] == dbInstId
        return inst[:endpoint][:address]
      end
    end
    return nil
  end

  def getRdsInstanceId(stackParams)
    #Change name by removing -drrep from name, in later versions also remove -dr from name
    newDbInstId = "keystone-" + stackParams.shard.downcase + '-' + stackParams.getEnvStripDr
    return newDbInstId
  end

  def getRdsLogInstanceId(stackParams)
    #Change name by removing -drrep from name, in later versions also remove -dr from name
    newDbInstId = "keystone-log-" + stackParams.shard.downcase + '-' + stackParams.getEnvStripDr
    return newDbInstId
  end

  def getRdsReplicaInstanceId(stackParams)
    #Change name by removing -drrep from name, in later versions also remove -dr from name
    newDbInstId = "keystone-" + stackParams.shard.downcase + '-rep-' + stackParams.getEnvStripDr
    return newDbInstId
  end

  def getRdsDrReplicaInstanceId(stackParams)
    #Change name by removing -drrep from name, in later versions also remove -dr from name
    newDbInstId = "keystone-" + stackParams.shard.downcase + '-drrep-' + stackParams.getEnvStripDr
    return newDbInstId
  end

  #
  # Return Hash or rds info including:
  #   - EndPoint
  #   - InstanceClass
  #   - Iops
  #   - Storage
  #   - Status
  #   - MultiAz
  #   - SecondaryAvailabilityZone
  #   - AvailabilityZone
  #
  def getRdsInfo(dbInstId)
    #puts "Getting RDS info for #{dbInstId}"
    info = Hash.new
    resp = @rds.client.describe_db_instances()
    resp.data[:db_instances].each do |inst|
      if inst[:db_instance_identifier] == dbInstId
        info['Endpoint'] = inst[:endpoint][:address]
        info['InstanceClass'] = inst[:db_instance_class]
        info['Status'] = inst[:db_instance_status]
        info['AvailabilityZone'] = inst[:availability_zone]
        info['SecondaryAvailabilityZone'] = inst[:secondary_availability_zone]
        info['MultiAz'] = inst[:multi_az]
        info['Storage'] = inst[:allocated_storage]
        info['Iops'] = inst[:iops]

      end
    end
    return info
  end

  def waitForRdsAvailable(dbInstId)
    status = getRdsStatus(dbInstId)
    puts "Waiting for RDS #{dbInstId} available status, current status: #{status}"
    until status == RDS_AVAILABLE_STATUS do
      puts "Waiting for RDS #{dbInstId} available status, current status: #{status}"
      sleep(10)
      status = getRdsStatus(dbInstId)
      if status == nil
        puts "RDS instance #{dbInstId} cannot be found"
        return
      end
    end
  end

  def waitForRdsStatusToChangeFrom(dbInstId, changeStatus)
    status = getRdsStatus(dbInstId)
    puts "Waiting for RDS #{dbInstId} status to change from #{changeStatus}, current status: #{status}"
    until status != changeStatus do
      puts "Waiting for RDS #{dbInstId} status to change from #{changeStatus}, current status: #{status}"
      sleep(10)
      status = getRdsStatus(dbInstId)
      if status == nil
        puts "RDS instance #{dbInstId} cannot be found"
        return
      end
    end
  end

  def modifyXRegionReadRep(replicaDbInstId, dbSecurityGroupId, dbParameterGroupName)
    modifySecurityParameterGroups(replicaDbInstId, dbSecurityGroupId, dbParameterGroupName)
    sleep(20)
    waitForRdsAvailable(replicaDbInstId)
    rebootRdsInstance(replicaDbInstId)
    waitForRdsAvailable(replicaDbInstId)
  end

  def modifySecurityParameterGroups(dbInstId, dbSecurityGroup, dbParameterGroup)
    puts "Modifying cross region replica #{dbInstId}, using secgrp #{dbSecurityGroup} and parameter group #{dbParameterGroup}"
    opts = Hash.new
    opts[:db_instance_identifier] = dbInstId
    opts[:vpc_security_group_ids] = [dbSecurityGroup]
    opts[:db_parameter_group_name] = dbParameterGroup
    opts[:apply_immediately] = true
    resp = @rds.client.modify_db_instance(opts)
  end

  def modifyRdsToMultiAz(dbInstId)
    puts "Modifying RDS instance #{dbInstId} to MultiAz"
    opts = Hash.new
    opts[:db_instance_identifier] = dbInstId
    opts[:multi_az] = true
    opts[:apply_immediately] = true
    resp = @rds.client.modify_db_instance(opts)
    puts "Modifed RDS instance #{dbInstId} to MultiAz"
  end

  #
  # arn:aws:rds:<region>:<account number>:<resourcetype>:<name>
  # "keystone-2-dev-nagift-dbparameters-keystonesubnetgroup-19vs3gdwn6q6a"
  #
  #    ./deploy_keystone_dr_replica.sh -e DEV -a $AWS_ACCESS_KEY -s $AWS_SECRET_KEY -r sa-east-1 --source-db-instance-identifier arn:aws:rds:us-west-2:593917551679:db:keystone-nagift-dev
  #
  def createXRegionReadRep(instId, sourceDbInstId, subnetGrp)
    puts "Creating cross region replica #{instId}"
    opts = Hash.new
    opts[:db_instance_identifier] = instId
    opts[:source_db_instance_identifier] = sourceDbInstId
    opts[:db_subnet_group_name] = subnetGrp
    @rds.client.create_db_instance_read_replica(opts)
  end

  def rebootRdsInstance(dbInstId)
    puts "Rebooting cross region replica #{dbInstId}"
    opts = Hash.new
    opts[:db_instance_identifier] = dbInstId
    @rds.client.reboot_db_instance(opts)
  end

  def createRdsXRegionReplica(replicaDbInstId, sourceDbArnId, replicaDbSubnetGrp, dbSecurityGroupId, dbParameterGroupName)
    createXRegionReadRep(replicaDbInstId, sourceDbArnId, replicaDbSubnetGrp)
    waitForRdsAvailable(replicaDbInstId)
    modifySecurityParameterGroups(replicaDbInstId, dbSecurityGroupId, dbParameterGroupName)
    sleep(20)
    waitForRdsAvailable(replicaDbInstId)
    rebootRdsInstance(replicaDbInstId)
    waitForRdsAvailable(replicaDbInstId)
  end

  def promoteRdsReplica(replicaDbInstId)
    puts "Promoting cross region replica #{replicaDbInstId}"
    opts = Hash.new
    opts[:db_instance_identifier] = replicaDbInstId
    @rds.client.promote_read_replica(opts)
    sleep(20)
    waitForRdsAvailable(replicaDbInstId)
  end

  def changeRdsDbInstanceIdentifier(currentInstId, newInstId)
    # Just remove -rep
    puts "Changing RDS DB Instance Identifier from #{currentInstId} to #{newInstId}"
    opts = Hash.new
    opts[:db_instance_identifier] = currentInstId
    opts[:new_db_instance_identifier] = newInstId
    opts[:apply_immediately] = true
    resp = @rds.client.modify_db_instance(opts)
    puts "resp = #{resp}"
    sleep(20)
    waitForRdsStatusToChangeFrom(currentInstId, RDS_MODIFYING_STATUS)
    sleep(20)
    waitForRdsStatusToChangeFrom(currentInstId, RDS_RENAMING_STATUS)
    sleep(20)
    waitForRdsStatusToChangeFrom(newInstId, RDS_REBOOTING_STATUS)
    sleep(10)
    waitForRdsAvailable(dbInstId)
  end

  def changeRdsDbInstanceIdentifierMakeMultiAz(currentInstId, newInstId)
    # Just remove -rep
    puts "Changing RDS DB Instance Identifier from #{currentInstId} to #{newInstId} and making MulitAZ"
    opts = Hash.new
    opts[:db_instance_identifier] = currentInstId
    opts[:new_db_instance_identifier] = newInstId
    opts[:multi_az] = true
    opts[:apply_immediately] = true
    resp = @rds.client.modify_db_instance(opts)
    sleep(20)
    waitForRdsStatusToChangeFrom(currentInstId, RDS_MODIFYING_STATUS)
    sleep(20)
    waitForRdsStatusToChangeFrom(currentInstId, RDS_RENAMING_STATUS)
    sleep(20)
    waitForRdsStatusToChangeFrom(newInstId, RDS_REBOOTING_STATUS)
    sleep(10)
    waitForRdsAvailable(newInstId)
  end
end

if __FILE__==$0
  puts "Starting"
  stackBuild = StackBuildParams.new
  stackBuild.modparam = nil
  stackBuild.stacks= ['1']
  stackBuild.accesskey = ENV['AWS_ACCESS_KEY']
  stackBuild.region = 'us-west-2'
  stackBuild.secretkey = ENV['AWS_SECRET_KEY']
  stackBuild.shard = 'NAGift'
  stackBuild.env = 'dev'
  stackBuild.profile = KSDeployProperties::PROFILE_MEDIUM


  replicaDbInstId = "keystone-nagift-drrep-dev"
  sourceDbArn = "arn:aws:rds:us-west-2:593917551679:db:keystone-nagift-dev"
  replicaDbSubnetGrpName = "keystone-2-dev-dr-nagift-dbparameters-keystonesubnetgroup-yda7vasn6hy3"
  dbSecurityGroupId = 'sg-8ea25ceb'
  dbParameterGroupName = 'keystone-2-dev-dr-nagift-dbparameters-keystonedbparametergroup-1vkclddzfgw8p'

  inst = KSRdsUtil.new(stackBuild)

  #inst.createRdsXRegionReplica(replicaDbInstId, sourceDbArn, replicaDbSubnetGrpName, dbSecurityGroupId, dbParameterGroupName)
  #rdsEndpoint = inst.getRdsEndpoint('keystone-igift-dev')
  #puts "rdaEndpoint - #{rdsEndpoint}"

  infoHash = inst.getRdsInfo('keystone-igift-dev')
  infoHash.each do |key, value|
    puts "#{key}: #{value}"
  end

  #puts "Changing RDS name"
  #inst.changeRdsDbInstanceIdentifierMakeMultiAz('keystone-nagift-drrep-dev-dr', 'keystone-nagift-dev-dr')
end
