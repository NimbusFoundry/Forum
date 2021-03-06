// Generated by CoffeeScript 1.8.0
(function() {
  var define_controller;

  define('account', function(require) {
    var doc_plugin;
    return doc_plugin = {
      type: 'plugin',
      title: 'Account',
      anchor: '#/account',
      _models: {},
      name: 'account',
      version: 1.0,
      order: -14,
      icon: 'icon-cog',
      init: function() {
        foundry.initialized(this.name);
        define_controller();
      }
    };
  });

  define_controller = function() {
    return angular.module('foundry').controller('AccountController', [
      '$scope', '$rootScope', '$foundry', '$filter', function($scope, $rootScope, $foundry, $filter) {
        var payment_gate, plan_to_usernumber, request_purchase;
        $rootScope.breadcum = 'Account';
        $scope.current_user_role = foundry._user_list[foundry._current_user.id].role;
        plan_to_usernumber = {
          0: "10",
          1: "25",
          2: "50",
          3: "infinite"
        };
        payment_gate = 'http://192.241.167.76:4000/buy/';
        $scope.get_plan = function() {
          return foundry._owner_plan;
        };
        $scope.usernumber = plan_to_usernumber[foundry._owner_plan];
        $scope.users = Nimbus.keys(foundry._user_list).length;
        $scope.is_current_plan = function(plan) {
          if (plan === $scope.get_plan()) {
            return 'current';
          } else if (plan > $scope.get_plan()) {
            return 'up';
          } else {
            return 'down';
          }
        };
        if (foundry.get_setting("email") == null) {
          $scope.setting_email = true;
        } else {
          $scope.setting_email = foundry.get_setting("email");
        }
        $scope.setting_email_change = function(status) {
          console.log("called");
          return foundry.set_setting("email", status);
        };
        request_purchase = function(level) {
          $.ajax({
            url: payment_gate + level + '/' + foundry._current_user.id + '/' + foundry._current_user.name,
            method: 'GET',
            success: function(data, status, req) {
              google.payments.inapp.buy({
                'jwt': data,
                'success': function(res) {
                  return console.log('success', res);
                },
                'failure': function(err) {
                  return console.log('err', err);
                }
              });
            }
          });
        };
        $scope.change_plan = function(level) {
          return request_purchase(level);
        };
        return window.a_scope = $scope;
      }
    ]);
  };

}).call(this);
