class StackBuildParams
  attr_accessor :env, :accesskey, :secretkey, :region, :drregion, :shard, :modparam, :stacks, :instancenumber, :profile, :changeprops, :initdb, :cutover, :dalarms, :drrdsendpoint, :drrdsinstid


  #Profiles (uses ||= to avoid already inited warning)
  PROFILE_TINY ||= 'tiny'
  PROFILE_MEDIUM ||= 'medium'
  PROFILE_LARGE ||= 'large'

  def to_s
    "StackBuildParams - env: #{env} accesskey: #{accesskey} secretkey: #{secretkey} region: #{region} shard: #{shard} modparam: #{modparam} stacks: #{stacks} instancenumber: #{instancenumber} profile: #{profile} initdb: #{initdb} cutover: #{cutover} changeprops: #{changeprops} dalarms: #{dalarms} drregion: #{drregion} drrdsendpoint #{drrdsendpoint} drrdsinstid #{drrdsinstid}"
  end

  def getEnvStripDr()
    #Remove dr- suffix after template mappings are fixed
    #return env.downcase.sub('-dr','')
    return env
  end

  def getCacheKey
    return (region + '_' + env + '_' + shard).downcase
  end

  def ==(o)
    puts "== called"
    o.class == self.class && o.state == state
  end

  alias_method :eql?, :==

  protected

  def state
    [env, accesskey, secretkey, region, drregion, shard, modparam, stacks, instancenumber, profile, changeprops, initdb, cutover, dalarms, drrdsendpoint, drrdsinstid]
  end
end

if __FILE__==$0
  stackBuild1 = StackBuildParams.new
  stackBuild1.modparam = nil
  stackBuild1.stacks= ['1']
  stackBuild1.accesskey = ENV['AWS_ACCESS_KEY']
  stackBuild1.region = 'us-west-2'
  stackBuild1.secretkey = ENV['AWS_SECRET_KEY']
  stackBuild1.shard = 'NAGift'
  stackBuild1.env = 'dev'
  stackBuild1.profile = 'medium'

  stackBuild2 = StackBuildParams.new
  stackBuild2.modparam = nil
  stackBuild2.stacks= ['1']
  stackBuild2.accesskey = ENV['AWS_ACCESS_KEY']
  stackBuild2.region = 'us-west-2'
  stackBuild2.secretkey = ENV['AWS_SECRET_KEY']
  stackBuild2.shard = 'NAGift'
  stackBuild2.env = 'dev'
  stackBuild2.profile = 'large'

  puts "Is eql - #{stackBuild1.eql? stackBuild2}"

end
