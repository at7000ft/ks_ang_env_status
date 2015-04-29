require 'aws-sdk'

require_relative './stack_build_params.rb'


class KSCwUtil

  KEYSTONE_ALARM_TOPIC_LOG_ID = "KeystoneMetricAlarmTopic"


  def initialize(stackParams)
    begin
      @cf = AWS::CloudFormation.new(
          :access_key_id => stackParams.accesskey,
          :secret_access_key => stackParams.secretkey,
          :region => stackParams.region)
      @cw = AWS::CloudWatch.new(
          :access_key_id => stackParams.accesskey,
          :secret_access_key => stackParams.secretkey,
          :region => stackParams.region)
      @stackParams = stackParams
    rescue Exception => error
      puts "KSCwUtil>>initialize: error " + e.message
      raise StandardError.new("KSCwUtil>>initialize: error  #{e.message}");
    end
  end

  def putMetricData(namespace, metricname, value)
    @cw.put_metric_data(
        :namespace => namespace,
        :metric_data => [
            {:metric_name => metricname, :value => value}

        ]
    )

  end

  def addRdsAlarm(alarmname, metricname, namespace, statistic, unit, evaluation_periods, threshold, comparison_operator)
    snsTopicPhyId = @cf.getStackResource(KSCfUtil.getStackname(@stackParams, ALARM_SNS_SUFFIX, nil), KEYSTONE_ALARM_TOPIC_LOG_ID, nil)
    if snsTopicPhyId.nil?
      puts "Error: KeystoneMetricAlarmTopicARN not found"
      return
    end
    puts "snsTopicPhyId - #{snsTopicPhyId}"

    #dimensions = [{"DBInstanceIdentifier" => "keystone-" + @stackParams.shard.downcase + '-' + @stackParams.env.downcase}]
    dimensions = [{'name' => "DBInstanceIdentifier", 'value' => "keystone-" + @stackParams.shard.downcase + '-' + @stackParams.env.downcase}]
    opts = Hash.new
    opts[:alarm_name] = alarmname
    opts[:actions_enabled] = true
    opts[:alarm_actions] = [snsTopicPhyId]
    opts[:metric_name] = metricname
    opts[:namespace] = namespace
    opts[:statistic] = statistic
    opts[:dimensions] = dimensions
    opts[:period] = 300
    opts[:unit] = unit
    opts[:evaluation_periods] = evaluation_periods
    opts[:threshold] = threshold
    opts[:comparison_operator] = comparison_operator


    @cw.client.put_metric_alarm(opts)
    puts "New CW alarm #{alarmname} created"
  end

  def addASGAlarm(alarmname, metricname, namespace, statistic, unit, evaluation_periods, threshold, comparison_operator, asgStackSuffix, topicLogicalId, asgLogicalId)
    snsTopicPhyId = @cf.getStackResource(KSCfUtil.getStackname(@stackParams, asgStackSuffix, nil), topicLogicalId, nil)
    if snsTopicPhyId.nil?
      puts "Error: #{topicLogicalId} not found"
      return
    end
    puts "snsTopicPhyId - #{snsTopicPhyId}"


    asgGroupName = @cf.getStackResource(KSCfUtil.getStackname(@stackParams, asgStackSuffix, nil), asgLogicalId, nil)
    if asgGroupName.nil?
      puts "Error: #{asgLogicalId} not found"
      return
    end
    puts "asgGroupName - #{asgGroupName}"

    #dimensions = [{"DBInstanceIdentifier" => "keystone-" + @stackParams.shard.downcase + '-' + @stackParams.env.downcase}]
    dimensions = [{'name' => "AutoScalingGroupName", 'value' => asgGroupName}]
    opts = Hash.new
    opts[:alarm_name] = alarmname
    opts[:actions_enabled] = true
    opts[:alarm_actions] = [snsTopicPhyId]
    opts[:metric_name] = metricname
    opts[:namespace] = namespace
    opts[:statistic] = statistic
    opts[:dimensions] = dimensions
    opts[:period] = 60
    opts[:unit] = unit
    opts[:evaluation_periods] = evaluation_periods
    opts[:threshold] = threshold
    opts[:comparison_operator] = comparison_operator


    @cw.client.put_metric_alarm(opts)
    puts "New CW alarm #{alarmname} created"
  end


end

if __FILE__==$0

  LOGSTASH_ALARM_TOPIC = "NotificationTopic"
  LOGSTASH_ASG_LOGICAL_ID = "LogstashAutoScalingGroup"

  KSDeploy.setTemplatePath(KSDeploy::TEMPLATE_PATH)
  KSDeploy.setPropertiesPath(KSDeploy::PROPERTIES_PATH)

  stackBuild = StackBuildParams.new
  stackBuild.modparam = nil
  stackBuild.stacks= ['1']
  stackBuild.accesskey = ENV['AWS_ACCESS_KEY']
  stackBuild.region = 'us-west-2'
  stackBuild.secretkey = ENV['AWS_SECRET_KEY']
  stackBuild.shard = 'Common'
  stackBuild.env = 'dev'
  stackBuild.profile = KSDeployProperties::PROFILE_MEDIUM


  dep = KSCwUtil.new(stackBuild)
  #dep.addRdsAlarm('Test2-' + stackBuild.env.upcase + '-' + stackBuild.shard + "-RdsCpuAlarm", "CPUUtilization", "AWS/RDS", "Average", "Percent", 2,"80","GreaterThanThreshold")
  #dep.addRdsAlarm('Keystone-2-' + stackBuild.env.upcase + '-' + stackBuild.shard + "-RdsStorageAlarm", "FreeStorageSpace", "AWS/RDS", "Average", "Bytes", 2,"100000000","LessThanThreshold")

  #dep.addASGAlarm('KSIgnore-' + stackBuild.env.upcase + '-' + stackBuild.shard + "-LogstashCpuHigh", "CPUUtilization", "AWS/EC2", "Average", "Percent", 2,"90","GreaterThanThreshold",KSCwUtil::LOGSTASH_STACK_SUFFIX, LOGSTASH_ALARM_TOPIC, LOGSTASH_ASG_LOGICAL_ID)

  #dep.addASGAlarm('KSIgnore-' + stackBuild.env.upcase + '-' + stackBuild.shard + "-LogstashCpuLow", "CPUUtilization", "AWS/EC2", "Average", "Percent", 2,"70","LessThanThreshold",KSCwUtil::LOGSTASH_STACK_SUFFIX, LOGSTASH_ALARM_TOPIC, LOGSTASH_ASG_LOGICAL_ID)

  #
  #aws cloudwatch describe-alarms-for-metric --metric run-status --namespace BHN/KS/AnnualFees-Keystone-2-DEV-NAGift-Batch
  #

  #Send a 0 run status Batch metric
  puts "Putting metric data for BHN/KS/AnnualFees-Keystone-2-DEV-IGift-Batch"
  dep.putMetricData('BHN/KS/AnnualFees-Keystone-2-DEV-IGift-Batch', 'run-status', 88)
  puts "Putting metric data for BHN/KS/BankFileGen-Keystone-2-DEV-IGift-Batch"
  dep.putMetricData('BHN/KS/BankFileGen-Keystone-2-DEV-IGift-Batch', 'run-status', 88)
  puts "Putting metric data for BHN/KS/ExpireHolds-Keystone-2-DEV-IGift-Batch"
  dep.putMetricData('BHN/KS/ExpireHolds-Keystone-2-DEV-IGift-Batch', 'run-status', 88)
  puts "Putting metric data for BHN/KS/NegBalMgt-Keystone-2-DEV-IGift-Batch"
  dep.putMetricData('BHN/KS/NegBalMgt-Keystone-2-DEV-IGift-Batch', 'run-status', 88)
  puts "Putting metric data for BHN/KS/Recon-Keystone-2-DEV-IGift-Batch"
  dep.putMetricData('BHN/KS/Recon-Keystone-2-DEV-IGift-Batch', 'run-status', 88)
end