//
// Base AngularJS module
//    - cgBusy pulls in angular-busy module which displays a wait dialog on all $http communication
//

var app = angular.module('KeystoneEnvStatus', ['templates','cgBusy']);

app.constant('version', '0.6.0');


