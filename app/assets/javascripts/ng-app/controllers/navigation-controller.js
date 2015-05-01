//
// NavController, uses AwsService to make rest/json calls to the Rails server and provide the data
// to the views.
//
// The version var is defined as a constant in app.js
//
var app = angular.module('KeystoneEnvStatus');
app.controller('NavController', function ($scope, $http, $log, AwsService, version) {
   $log.info("NavController: running version " + version);

   //The current AWS region client is viewing, init to us-west-2
   this.currentRegion = "us-west-2";
   this.version = version;



   //The current shard the client is viewing, 'all' is to view all environments
   this.shard = "all";

   // Define a variable that can be used by callbacks that reference this controller
   var status = this;
   status.envsStatus = {};
   status.shardInfo = null;
   status.currentEnvironment = '';

   //Error message string displayed below navbar if > 0
   status.errorMessage = '';

   this.regions = function () {
      AwsService.regions().then(function (resp) {
            $log.info("regions returned - " + resp.data);
            //Load regions variable for the navbar dropdown to show
            status.regions = resp.data;
         },
         function (error) {
            $log.error('regions failure ', error.message);
         });
   }

   //Return true or false based on passed in shard name equals currently selected shard
   this.isSelectedShard = function (inshard) {
      //$log.info("isSelectedShard with " + inshard);
      return this.shard == inshard;
   }

   //Request server to flush data caches
   this.flushCaches = function () {
      $log.info("flushCaches: called, shard = " + this.shard);
      status.errorMessage = '';
      // Change view to environments (if not already there)
      //this.shard = "all";

      AwsService.flushCaches(this.shard,this.currentEnvironment, this.currentRegion).then(function (resp) {
            $log.info("flushCaches called");
            window.location.reload();
         },
         function (error) {
            $log.error('flushCaches failure - ', error.data.message);
            status.errorMessage = error.data.message;
         });
      //AwsService.flushCaches().
      //   success(function (data, status, headers, config) {
      //      $log.info("flushCaches called");
      //   }).
      //   error(function (data, status, headers, config) {
      //      $log.error('flushCaches failure ', error);
      //   });

      //$http.get('/api/v1/flushCaches').
      //   success(function (data, status, headers, config) {
      //      $log.info("flushCaches success, status - " + status);
      //   }).
      //   error(function (data, status, headers, config) {
      //      $log.error('flushCaches failure ', status);
      //   });
   }

   //Request the status of all environments in the AWS region passed in
   this.updateForRegion = function (region) {
      $log.info("updateForRegion called with " + region);
      this.currentRegion = region;

      // Change view to environments (if not already there)
      this.shard = "all";

      this.httpPromise = AwsService.envsStatus(region).then(function (resp) {
            $log.info("envsStatus resp data - " + JSON.stringify(resp.data));
            status.envsStatus = resp.data;
         },
         function (error) {
            $log.error('envsStatus failure ', error);

         }).then(function () {
            // "complete" code here, after first then or error processed

         });
   };

   //Request status info from the server for passed in shard and environment
   this.updateShard = function (shard, env) {
      $log.info("updateShard called with " + shard + " and " + env);
      this.currentEnvironment = env;
      this.shard = shard;

      if (shard == 'common') {
         this.rdsType = "Log";
      } else {
         this.rdsType = "";
      }

      updateRegion = this.currentRegion;
      updateEnv = env;

      this.httpPromise = AwsService.shardStatus(updateRegion, updateEnv, shard).then(function (resp) {
            $log.info("shardStatus resp data - " + JSON.stringify(resp.data));

            status.shardInfo = resp.data;
            status.shard = shard;

         },
         function (error) {
            $log.error('shardStatus failure ', error);

         }).then(function () {

         });
   };

   this.hasRdsInfo = function () {
      //$log.info("hasRdsInfo:status.shardInfo = " + status.shardInfo);
      if (status.shardInfo == null || status.shardInfo.rds_info == null) {
         return false;
      } else {
         return true;
      }
   }

   this.hasRdsRepInfo = function () {
      //$log.info("hasRdsRepInfo:status.shardInfo = " + status.shardInfo);
      if (status.shardInfo == null || status.shardInfo.rds_rep_info == null) {
         return false;
      } else {
         return true;
      }
   }

   this.hasEc2Info = function () {
      //$log.info("hasEc2Info:status.shardInfo = " + status.shardInfo);
      if (status.shardInfo == null || status.shardInfo.ec2_info == null) {
         return false;
      } else {
         return true;
      }
   }

   //Request an AWS environment startup on the server
   this.startEnv = function (env) {
      $log.info("startEnv called with " + env);

      this.httpPromise = AwsService.startEnv(this.currentRegion, env).then(function (resp) {
            $log.info("startEnv completed");
         },
         function (error) {
            $log.error('startEnv failure ', error);

         }).then(function () {
            // Reinit environments view data
            status.updateForRegion(status.currentRegion);
         });
   };

   //Request an AWS environment stop on the server
   this.stopEnv = function (env) {
      $log.info("stopEnv called with " + env);

      this.httpPromise = AwsService.stopEnv(this.currentRegion, env).then(function (resp) {
            $log.info("stopEnv completed");
         },
         function (error) {
            $log.error('stopEnv failure ', error);

         }).then(function () {
            // Reinit environments view data
            status.updateForRegion(status.currentRegion);
         });
   };

   // Init regions array and environments view with status data for us-west-2 region. Only called here when controller/app first loads.
   this.regions();
   this.updateForRegion('us-west-2');
});

app.factory('httpInterceptor', ['$location', '$q', function ($location, $q) {
   return function (promise) {
      promise.then(
         function (response) {
            console.log("httpInterceptor: called with " + response);
            return response;
         },
         function (response) {
            console.log("httpInterceptor: error - " + response);
            return $q.reject(response);
         }
      );
      return promise;
   };
}]);

app.config(function ($httpProvider) {
   $httpProvider.interceptors.push('httpInterceptor');
});

