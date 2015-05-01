#
# Title: KSConstants
# Description: 
#
# Author: rholl00 
# Date: 4/8/15
#

module KSCommon
  #Stack states
  STATUS_CREATE_IN_PROGRESS = 'CREATE_IN_PROGRESS'
  STATUS_UPDATE_IN_PROGRESS = 'UPDATE_IN_PROGRESS'
  STATUS_ROLLBACK_IN_PROGRESS = 'ROLLBACK_IN_PROGRESS'
  STATUS_ROLLBACK_COMPLETE = 'ROLLBACK_COMPLETE'
  STATUS_UPDATE_COMPLETE = 'UPDATE_COMPLETE'
  STATUS_CREATE_COMPLETE = 'CREATE_COMPLETE'
  STATUS_UPDATE_ROLLBACK_COMPLETE = 'UPDATE_ROLLBACK_COMPLETE'
  STATUS_UPDATE_ROLLBACK_IN_PROGRESS = 'UPDATE_ROLLBACK_IN_PROGRESS'
  STATUS_DELETE_IN_PROGRESS = 'DELETE_IN_PROGRESS'
  STATUS_DELETE_FAILED = 'DELETE_FAILED'

  #ASG status
  STATUS_RUNNING = 'Running'
  STATUS_SUSPENDED = 'Suspended'

  #Deploy modes
  MODE_CREATE = 'CREATE'
  MODE_UPDATE = 'UPDATE'

  #create/update status
  CREATE_UPDATE_SUCCESS = "Success"
  CREATE_UPDATE_FAILURE = "Failure"

  #Stack suffixes
  ROLES_STACK_SUFFIX = "Roles"
  S3_STACK_SUFFIX = "S3"
  DB_PARAMETERS_STACK_SUFFIX="DBParameters"
  DB_STACK_SUFFIX = "DB"
  REPLICA_DB_PARAMETERS_STACK_SUFFIX="ReplicaDBParameters"
  REPLICA_DB_STACK_SUFFIX = "ReplicaDB"
  LOG_DB_STACK_SUFFIX = "LogDB"
  LOG_DB_PARAMETERS_STACK_SUFFIX="LogDBParameters"
  TRANSIENT_STACK_SUFFIX = "Transient"
  USERS_ROLES_TRANSIENT_STACK_SUFFIX = "UsersRolesTransient"
  DB_TRANSIENT_SECGRP_STACK_SUFFIX = "DBTransientSecurityGroup"
  LOG_DB_TRANSIENT_STACK_SUFFIX = "LogDBTransient"
  LOG_DB_TRANSIENT_SECGRP_STACK_SUFFIX = "LogDBTransientSecGrp"
  COMMON_SECGRP_STACK_SUFFIX = "CommonSecurityGroup"
  KERNEL_SECGRP_STACK_SUFFIX = "KernelSecurityGroup"
  SERVICES_SECGRP_STACK_SUFFIX = "ServicesSecurityGroup"
  PORTAL_SECGRP_STACK_SUFFIX = "PortalSecurityGroup"
  LOGSTASH_SECGRP_STACK_SUFFIX = "LogstashSecurityGroup"
  BATCH_SECGRP_STACK_SUFFIX = "BatchSecurityGroup"
  BASTION_SECGRP_STACK_SUFFIX = "BastionSecurityGroup"
  PORTAL_GWY_SECGRP_STACK_SUFFIX = "PortalGatewaySecurityGroup"
  PORTAL_ELB_SECGRP_STACK_SUFFIX = "PortalElbSecurityGroup"
  LOGSTASH_ELB_SECGRP_STACK_SUFFIX = "LogstashElbSecurityGroup"
  SERVICES_ELB_SECGRP_STACK_SUFFIX = "ServicesElbSecurityGroup"
  KERNEL_ELB_SECGRP_STACK_SUFFIX = "KernelElbSecurityGroup"
  PORTAL_GWY_ELB_SECGRP_STACK_SUFFIX = "PortalGatewayElbSecurityGroup"
  SERVICES_GWY_SECGRP_STACK_SUFFIX = "ServicesGatewaySecurityGroup"
  SECURITY_GWY_ELB_SECGRP_STACK_SUFFIX = "SecurityGatewayElbSecurityGroup"
  SYSLOG_SECGRP_STACK_SUFFIX = "SyslogSecurityGroup"
  SECGRP_STACK_SUFFIX = "SecGrp"
  ENI_STACK_SUFFIX = "ENI"
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
  SERVICES_ELB_STACK_SUFFIX = "ServicesElb"
  KERNEL_ELB_STACK_SUFFIX = "KernelElb"
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
  ALARM_LOG_RDS_STACK_SUFFIX = "AlarmLogRds"
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

  LOG_DB_ADMIN_USER = 'kys_syslog_admin'
  LOG_DB_ADMIN_PASSWORD = 'kys_syslog_admin'

  IAM_ROLE_KSCCW_WRITE_PROFILE = 'KSCWMailWriteProfile'
  IAM_ROLE_BATCH_PROFILE = 'KSBatchProfile'

  KYS_RDS_PORT = '3306'

  MERGING_SCALE_KEY = 'MergingScale'
  MERGE_SCALE = 'merge'
  NO_MERGE_SCALE = 'nomerge'
  METRIC_ALARM_TOPIC_NAME = 'KeystoneMetricAlarmTopic'

  #Profiles
  PROFILE_TINY = 'tiny'
  PROFILE_MEDIUM = 'medium'
  PROFILE_LARGE = 'large'


  VALID_ENVS = ['DEV', 'DEV-DR', 'QA-M', 'QA-M-DR', 'QA-P', 'QA-R', 'KERNEL', 'KERNEL1', 'KONE', 'KONE-DR', 'DEMO', 'CERT', 'BI', 'LI', 'HA', 'PERF', 'PP', 'PP-DR', 'PROD', 'PROD-DR', 'PERF-DR', 'CI']
  VALID_SHARDS = ['Common', 'NAGPR', 'NAGift', 'IGift', 'IGPR', 'CLoop']
  VALID_INITDB = ['true', 'false']
  VALID_CUTOVER = ['true', 'false']


  #Shard profiles - EC2 instance count, instance type, ebs volume size
  # tiny - (no HA) single instance count, small instance types, min volume size
  # small - (min HA) single instance in each AZ, small instance types, min volume size
  # med - (med HA) single instance in each AZ, medium instance types, med volume size
  # large - (prod and perf) full size
  #VALID_PROFILES = ['tiny', 'medium', 'large']

  KERNEL_STACK_SUFFIX_MAP = {'1' => "KeystoneKernel1Stack", '2' => "KeystoneKernel2Stack", '3' => "KeystoneKernel3Stack", '4' => "KeystoneKernel4Stack"}

  SYSTEM_BASE_SHARDS = ['NAGift', 'IGift', 'CLoop', 'BES']

  #Shards
  COMMON_SHARD = 'Common'
  IGIFT_SHARD = 'IGift'
  NAGIFT_SHARD = 'NAGift'
  CLOOP_SHARD = 'CLoop'
  BES_SHARD = 'BES'

  #Paths
  TEMPLATE_PATH = '../../templates/'
  PROPERTIES_PATH = "../../properties"
  REGION_PROPERTIES_PATH = "../../properties/regions"

  def getStackname(stackParams, suffix, targetShard, applyInstanceNumber=true)
    #Check for  a CPS stack (sufix is the full stack prefix, like CPS-CPS-KONE)
    if suffix.start_with? 'CPS'
      return suffix + "-" + stackParams.getEnvStripDr.upcase
    end

    if targetShard.nil?
      stackNm = "Keystone-2-" + stackParams.getEnvStripDr.upcase + "-" + stackParams.shard
    else
      stackNm = "Keystone-2-" + stackParams.getEnvStripDr.upcase + "-" + targetShard
    end

    unless suffix.nil?
      stackNm += "-" + suffix
    end

    if applyInstanceNumber
      unless stackParams.instancenumber.nil?
        stackNm += stackParams.instancenumber
      end
    end

    return stackNm
  end

  def db_instance_name(stack_params)
    return 'keystone-' + stack_params.shard.downcase +  '-' + stack_params.env.downcase
  end

  def replica_db_instance_name(stack_params)
    return 'keystone-' + stack_params.shard.downcase + '-rep-' +  stack_params.env.downcase
  end

  def log_db_instance_name(stack_params)
    return 'keystone-log-common-' + stack_params.env.downcase
  end

  def rds_event_subscription_name(stack_params)
    return  'Keystone-2-' + stack_params.env.upcase + '-RDSEventSubscription'
  end

end