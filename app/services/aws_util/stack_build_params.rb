#
# StackBuildParams - Keystone container class which holds all build parameters
#
class StackBuildParams
  attr_accessor :env, :accesskey, :secretkey, :region, :drregion, :alternateregion, :shard, :modparam, :stacks, :instancenumber, :profile, :changeprops, :initdb, :cutover, :dalarms, :drrdsendpoint, :drrdsinstid

  def to_s
    "StackBuildParams - env: #{env} region: #{region} shard: #{shard} modparam: #{modparam} stacks: #{stacks} instancenumber: #{instancenumber} profile: #{profile} initdb: #{initdb} cutover: #{cutover} changeprops: #{changeprops} dalarms: #{dalarms} drregion: #{drregion} drrdsendpoint #{drrdsendpoint} drrdsinstid #{drrdsinstid}"
    #"StackBuildParams - env: #{env} accesskey: #{accesskey} secretkey: #{secretkey} region: #{region} shard: #{shard} modparam: #{modparam} stacks: #{stacks} instancenumber: #{instancenumber} profile: #{profile} initdb: #{initdb} cutover: #{cutover} changeprops: #{changeprops} dalarms: #{dalarms} drregion: #{drregion} drrdsendpoint #{drrdsendpoint} drrdsinstid #{drrdsinstid}"
  end

  def getEnvStripDr()
    #Remove dr- suffix after template mappings are fixed
    #return env.downcase.sub('-dr','')
    return env
  end

  def clone
    return Marshal.load( Marshal.dump(this) )
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
    [env, accesskey, secretkey, region, drregion, alternateregion, shard, modparam, stacks, instancenumber, profile, changeprops, initdb, cutover, dalarms, drrdsendpoint, drrdsinstid]
  end
end