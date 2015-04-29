#
# Title: TestAwsAccess
# Description: 
#
# Author: rholl00 
# Date: 2/25/15
#

require_relative '../../app/services/aws_access'

class TestAwsAccess



    def testEnvStatus
      #stackBuild = AwsAccess.getStackBuild('perf', 'us-west-2', 'NAGift')
      stackBuild = AwsAccess.getStackBuild('qa-m-dr', 'sa-east-1', 'CLoop')

      shardInfo = AwsAccess.getGiftStatus(stackBuild)
      puts "shardInfo - #{shardInfo}"

    end


end

test = TestAwsAccess.new
test.testEnvStatus
