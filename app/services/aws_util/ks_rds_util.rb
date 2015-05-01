require 'aws-sdk'

require_relative './stack_build_params.rb'
#require_relative '../../lib/ks_deploy_properties'


class KSRdsUtil

  include KSCommon

  ACCOUNT_ID_MAP = {'nonprod' => '593917551679', 'pp' => '524670336862', 'prod' => '???'}

  RDS_MODIFYING_STATUS = 'modifying'
  RDS_AVAILABLE_STATUS = 'available'
  RDS_REBOOTING_STATUS = 'rebooting'
  RDS_BACKING_UP_STATUS = 'backing-up'
  RDS_RENAMING_STATUS = 'renaming'


  def initialize(stackParams)
    @stackParams = stackParams
    #Run the local config.rb script to load AWS props and config AWS with keys and region
    begin
      #File.expand_path(File.dirname(__FILE__) + '/config')
      @rds = Aws::RDS::Client.new(
          :access_key_id => @stackParams.accesskey,
          :secret_access_key => @stackParams.secretkey,
          :region => @stackParams.region)

    rescue Exception => e
      puts "KSRdsUtil>>initialize: error " + e.message
    end
  end



  def create_event_subscription(name, topic_arn, categories, db_instance_names)
    sub_exists = false
    resp = nil
    begin
      #See if subscription exists
      resp = @rds.describe_event_subscriptions(subscription_name: name)
    rescue Exception => e
      unless e.message.include?('not found')
        raise
      end
    end
    begin
      unless resp.nil?
        current_db_inst_names = resp.data[:event_subscriptions_list][0][:source_ids_list]
        puts "RDS event subscription #{name} exists with db instances #{current_db_inst_names}"
        #Subscription exists, add new db instance names if not already there
        db_instance_names.each do |inst_name|
          unless current_db_inst_names.include?(inst_name)
            puts "Adding DB instance #{inst_name} to event subscription #{name}"
            @rds.add_source_identifier_to_subscription(subscription_name: name, source_identifier: inst_name)
          else
            puts "DB instance #{inst_name} already in event subscription #{name}"
          end
        end
      else
        #Create new event subscription
        options = {
            subscription_name: name,
            source_type: 'db-instance',
            sns_topic_arn: topic_arn,
            enabled: true
        }
        options[:event_categories] = categories unless categories.nil?
        options[:source_ids] = db_instance_names unless db_instance_names.nil?
        puts "Creating new RDS envent subscription named #{name} and db instances #{db_instance_names}"
        resp = @rds.create_event_subscription(options)
        return resp.data[:event_subscription][:status]
      end
    rescue Exception => e
      puts "create_event_subscription:  error " + e.message
    end
  end

  # def db_instance_name(stack_params)
  #   return 'keystone-' + stack_params.shard.downcase +  '-' + stack_params.env.downcase
  # end
  #
  # def replica_db_instance_name(stack_params)
  #   return 'keystone-' + stack_params.shard.downcase + '-rep-' +  stack_params.env.downcase
  # end
  #
  # def log_db_instance_name(stack_params)
  #   return 'keystone-log-common-' + stack_params.env.downcase
  # end
  #
  # def rds_event_subscription_name(stack_params)
  #   return  'Keystone-2-' + stack_params.env.upcase + '-RDSEventSubscription'
  # end

  def getRdsStatus(dbInstId)
    begin
      resp = @rds.describe_db_instances(db_instance_identifier: dbInstId)
      return resp[:db_instances][0][:db_instance_status]
    rescue Exception => e
      puts "KSRdsUtil>> Status of dbInstId :  " + e.message
    end
  end

  def getRdsEndpoint(dbInstId)
    resp = @rds.describe_db_instances(db_instance_identifier: dbInstId)
    return resp[:db_instances][0][:endpoint][:address]
  end

  def getRdsInstanceId(stackParams)
    envSuffix = stackParams.getEnvStripDr.downcase
    newDbInstId = "keystone-" + stackParams.shard.downcase + '-' + envSuffix
    return newDbInstId
  end

  def getRdsLogInstanceId(stackParams)
    #Change name by removing -drrep from name, in later versions also remove -dr from name
    newDbInstId = "keystone-log-" + stackParams.shard.downcase + '-' + stackParams.getEnvStripDr
    return newDbInstId
  end

  def getRdsReplicaInstanceId(stackParams)
    envSuffix = stackParams.getEnvStripDr.downcase
    newDbInstId = "keystone-" + stackParams.shard.downcase + '-rep-' + envSuffix
    return newDbInstId
  end

  def getRdsDrReplicaInstanceId(stackParams)
    #Change name by removing -drrep from name, in later versions also remove -dr from name
    newDbInstId = "keystone-" + stackParams.shard.downcase + '-drrep-' + stackParams.getEnvStripDr.downcase
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
    begin
      raise if dbInstId.nil?
      resp = @rds.describe_db_instances(db_instance_identifier: dbInstId)
    rescue
      #puts "getRdsInfo: RDS instance not found for #{dbInstId}"
      return info
    end
    inst = resp.data[:db_instances][0]
    if inst.nil?
      return info
    end
    begin
      info['Endpoint'] = inst[:endpoint][:address]
      info['InstanceClass'] = inst[:db_instance_class]
      info['Status'] = inst[:db_instance_status]
      info['AvailabilityZone'] = inst[:availability_zone]
      info['SecondaryAvailabilityZone'] = inst[:secondary_availability_zone]
      info['MultiAz'] = inst[:multi_az]
      info['Storage'] = inst[:allocated_storage]
      info['Iops'] = inst[:iops]
    rescue
      return info
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
    resp = @rds.modify_db_instance(opts)
  end

  def modifyRdsToMultiAz(dbInstId)
    puts "Modifying RDS instance #{dbInstId} to MultiAz"
    opts = Hash.new
    opts[:db_instance_identifier] = dbInstId
    opts[:multi_az] = true
    opts[:apply_immediately] = true
    resp = @rds.modify_db_instance(opts)
    puts "Modifed RDS instance #{dbInstId} to MultiAz"
  end

  #
  # arn:aws:rds:<region>:<account number>:<resourcetype>:<name>
  # "keystone-2-dev-nagift-dbparameters-keystonesubnetgroup-19vs3gdwn6q6a"
  #
  #    ./deploy_keystone_dr_replica.sh -e DEV -a $AWS_ACCESS_KEY -s $AWS_SECRET_KEY -r sa-east-1 --source-db-instance-identifier arn:aws:rds:us-west-2:593917551679:db:keystone-nagift-dev
  #
  def createXRegionReadRep(instId, sourceDbInstId, subnetGrp)
    puts "Creating cross region replica #{instId} from source DB #{sourceDbInstId} with subnet group #{subnetGrp}"

    begin
      opts = Hash.new
      opts[:db_instance_identifier] = instId
      opts[:source_db_instance_identifier] = sourceDbInstId
      opts[:db_subnet_group_name] = subnetGrp
      @rds.create_db_instance_read_replica(opts)
    rescue Exception => e
      puts "KSRdsUtil>>createXRegionReadRep: error " + e.message
    end

  end

  def rebootRdsInstance(dbInstId)
    puts "Rebooting cross region replica #{dbInstId}"
    opts = Hash.new
    opts[:db_instance_identifier] = dbInstId
    @rds.reboot_db_instance(opts)
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
    @rds.promote_read_replica(opts)
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
    resp = @rds.modify_db_instance(opts)
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
    resp = @rds.modify_db_instance(opts)
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
  stackBuild.profile = KSCommon::PROFILE_MEDIUM


  # replicaDbInstId = "keystone-nagift-drrep-dev"
  # sourceDbArn = "arn:aws:rds:us-west-2:593917551679:db:keystone-nagift-dev"
  # replicaDbSubnetGrpName = "keystone-2-dev-dr-nagift-dbparameters-keystonesubnetgroup-yda7vasn6hy3"
  # dbSecurityGroupId = 'sg-8ea25ceb'
  # dbParameterGroupName = 'keystone-2-dev-dr-nagift-dbparameters-keystonedbparametergroup-1vkclddzfgw8p'

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
