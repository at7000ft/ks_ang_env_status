#
# Title: KeystoneUtil module
# Description:
#
# Author: rholl00
# Date: 12/10/14
#
module KeystoneUtil
  VALID_ENVS = ['DEV', 'DEV-DR', 'QA-M', 'QA-M-DR', 'QA-P', 'QA-R', 'KERNEL', 'KERNEL1', 'KERNELONE', 'DEMO', 'CERT', 'BI', 'LI', 'HA', 'PERF', 'PP', 'PP-DR', 'PROD', 'PROD-DR', 'PERF-DR']
  VALID_SHARDS = ['Common', 'NAGPR', 'NAGift', 'IGift', 'IGPR', 'SFWY']
  COMMON_SHARD = 'Common'
  IGIFT_SHARD = 'IGift'
  NAGIFT_SHARD = 'NAGift'
  AWS_REGIONS_SELECT =[['US East (N. Virginia) - us-east-1','us-east-1'],['US West (Oregon) - us-west-2','us-west-2'], ['US West (N. California) - us-west-1','us-west-1'], ['EU (Ireland) - eu-west-1','eu-west-1'], ['EU (Frankfurt) - eu-central-1','eu-central-1'], ['Asia Pacific (Singapore) - ap-southeast-1','ap-southeast-1'], ['Asia Pacific (Sydney) - ap-southeast-2','ap-southeast-2'], ['Asia Pacific (Tokyo) - ap-northeast-1','ap-northeast-1'], ['South America (Sao Paulo) - sa-east-1','sa-east-1']]
  ENVIRONMENT_ARRAY_CACHE_KEY_PREFIX = "envArray"
  STATUS_MAP_KEY_PREFIX = "envStatusMap"

  CACHE_TIMEOUT_STACKS = 440*60  #minutes
  CACHE_TIMEOUT_LISTS = 480*60
  CACHE_TIMEOUT_SESSION = 20*60
end