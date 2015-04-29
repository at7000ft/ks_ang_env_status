require 'test_helper'

class AwsControllerTest < ActionController::TestCase
  # test "should get index" do
  #   get :index
  #   assert_response :success
  # end

  def testEnvStatus
    stackBuild = AwsAccess.getStackBuild('perf', 'us-west-2', 'nagift')

    shardInfo = AwsAccess.getGiftStatus(stackBuild)
    puts "shardInfo - #{shardInfo}"
    assert true
  end

  

end
