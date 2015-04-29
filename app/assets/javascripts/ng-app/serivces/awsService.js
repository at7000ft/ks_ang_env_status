//
// Define functions that use the $http service to make rest calls to
// the Rails controller. Return a Promise to the caller which they can pass
// a callback to run when the request completes.
//
angular.module('KeystoneEnvStatus').factory('AwsService', function ($http, $log) {
   return {
      regions: function () {
         console.log("AwsService: regions");
         return $http.get('/api/v1/regions');
      },
      flushCaches: function (shard,env,region) {
         console.log("AwsService: flushCaches");
         //return $http.get('/api/v1/flushCaches');
         return $http({
            url: '/api/v1/flushCaches',
            method: "GET",
            params: {shard: shard,env: env,region: region}
         });
      },

      stopEnv: function (region, env) {
         console.log("AwsService: stopEnv called with " + env);
         return $http({
            url: '/api/v1/stopEnv',
            method: "GET",
            params: {region: region, env: env}
         });
      },
      startEnv: function (region, env) {
         console.log("AwsService: startEnv called with " + env);
         return $http({
            url: '/api/v1/startEnv',
            method: "GET",
            params: {region: region, env: env}
         });
      },
      shardStatus: function (region, env, shard) {
         console.log("AwsService: shardStatus called with " + env);
         return $http({
            url: '/api/v1/shardStatus',
            method: "GET",
            params: {region: region, env: env, shard: shard}
         });
      },
      envsStatus: function (region) {
         console.log("AwsService: envsStatus called with " + region);
         return $http({
            url: '/api/v1/envsStatus',
            method: "GET",
            params: {region: region}
         });
      }
   }
});
