define('user',['require', 'core/analytic'],(require, analytic)->
	user_plugin = 	
		_models : {}
		title : 'Users'
		type : 'plugin'
		order : -12
		icon : 'icon-user'
		# initialize plugin,
		init : ()->
			
			self = @
			name = 'User'
			attributes = ['pid','name', 'role', 'email','pic', 'not_first_login', 'initied', 'rated', 'last_login_time']
			@_models['user'] = {}
			foundry.model(name, attributes,(model)->
				self._models['user'] = model
				foundry.initialized('user')
				return
			)
			return

		inited: ()->
			# init analyitc
			analytic.init()

			# check when all is finished
			@check_users()

			self = @

			user_model = foundry._models['User']

			# get the space owner
			for id,user of foundry._user_list
				if user.id is Nimbus.realtime.c_file.owners[0].permissionId
					foundry._current_owner = user

			inject_controller()
			# get user plan
			@get_user_plan((plan)->
				console.log 'plan : ',plan
				limit = [10, 25, 50]
				plan_type = [0,1,2,3]
				type = 0
				expired = false
				status = 1
				if plan
					type = Number(plan.order.type)
					expired = moment(plan.order.date).add('y',1) < moment.valueOf()
					status = plan.order.status
				return if foundry._current_user.id isnt foundry._current_owner.id
				
				if status is 0
					# prompt for cancellation
					msg = '<div style="padding:20px">Your subscription is canceled, Please repurchase it.</div>'
					self.alert_for_upgrade(msg)
				else if expired
					# check for plan expiration
					msg = '<div style="padding:20px">Your subscription is expired, Please update it.</div>'
					self.alert_for_upgrade(msg)
				else
					if type is 3
						console.log 'ultimate plan'
					else if Nimbus.keys(foundry._user_list).length > limit[type]
						#prompt for upgrade
						self.alert_for_upgrade()

			)

		check_users : ()->
			user_model = foundry._models['User']
			console.log 'user list total :'+Nimbus.keys(foundry._user_list).length+', user model total: '+user_model.all().length

			# remove user not in the _user_list variable
			for user in user_model.all()
				if !user.email
					user.destroy()

			# add pic and data to user model that not exsit
			for pid,user of foundry._user_list
				one = user_model.findByAttribute('pid', pid)
				# ad email
				if one
					if one.email
						user.email = one.email
						user.roleName=one.role 

				# save image or create this user
				if one and !one.pic
					one.pic = user.pic
					one.save()

				else if !one
					data = 
						'pid' : pid
						'name' : user.name
						'pic' : user.pic
					# with new nimbusbase api, can retrive the shared user's email

					data.email = user.email if user.email
					if Nimbus.realtime.c_file.owners[0].permissionId is pid
						data.role = 'Admin'
					else
						data.role = 'Viewer'
					# keep the email in place	
					if pid is foundry._current_user.id
						data.email = window.user_email
					user_model.create(data)

					# set type
					user.roleName = data.role

				one = user_model.findByAttribute('pid', pid)
				# append email to current user
				if pid is foundry._current_user.id
					if !one.not_first_login 
						one.not_first_login = 1
						one.save()

			return
		all_user : ()->
			# @_models['user'].sync_all()
			@_models['user'].all()
		add_user : (data, callback)->
			# check email
			if !data.role
				data.role = 'Viewer'

			model = @_models['user']
			user = model.findByAttribute('email',data.email)
			if !user
				user = model.create(data) 

			user.role = data.role
			user.save()
			
			# share
			@add_share(user, (data)->
				if callback
					callback(data)
			)

			# track this action
			analytic.user(
				email : foundry._current_user.email
				user : data.email
				id : foundry._current_user.id
			)
			
		add_share : (user, callback)->
			model = @_models['user']

			if user.email
				Nimbus.Share.add_share_user_real(user.email,(u)->
					if u.name
						# find user
						t = model.findByAttribute('email',user.email)
						# cun
						t.name = u.name
						t.pid = u.id
						t.pic = u.pic
						t.save()

					foundry._user_list[u.id] = 
						name : u.name
						pic : u.pic
						roleName : user.role
						email : user.email
						id : u.id
						role : u.role

					if callback
						callback(u)
						angular.element(document).scope().$apply()
				)	
				# share folder
				if Nimbus.realtime.folder and Nimbus.realtime.folder['binary_files']
					Nimbus.Share.add_share_user_real(user.email,null,Nimbus.realtime.folder['binary_files'].id)
					

		remove_share : (user)->
			# remove permission with permission id
			Nimbus.Share.remove_share_user_real(user.id,(res)->

			)
			return

		save_user : (id, data)->
			# update the user_list
			user = foundry._user_list[id]
			user.roleName = data.role

			user = @_models['user'].findByAttribute('pid',id)
			if user
				user.role = data.role
				user.save()

		# input : user object
		# output : callbak after this is excuted
		# remove a user data in the model, will return if the user exist or not
		del_user : (user, callback)->
			# only remove the list, do not touch metedata
			id = user.id
			@remove_share(user)
		
			if callback
				callback()

		# input : none
		# output : string
		# generate a mailing list of all user, maybe will exclude the current user
		mail_list : ()->
			recipients = ''
			i = 0
			for id,user of foundry._user_list
				continue if user.email is foundry._current_user.email

				if foundry.get_setting_all(id, "email")? and foundry.get_setting_all(id, "email") is false
					continue

				if i is 0 and user.email
					recipients += user.name + ' <'+user.email+'>'
				else if user.email
					recipients += ','+user.name + ' <'+user.email+'>'
				i++
			recipients

		# current workspace owner's paid plan
		user_plan : null

		# input - none
		# output - Boolean
		# to tell if current workspace can create more user or not
		get_user_plan : (callback)->
			self = @
			url = "http://192.241.167.76:4000/order/#{foundry._current_owner.id}/#{foundry._current_owner.email}"
			$.ajax(
				'url' : url
				success : (data)->
					if data
						user = data
						self.user_plan = foundry._owner_plan = Number(user.order.type)
					else
						user = false
						self.user_plan = foundry._owner_plan = 0
					callback(user) if callback
			)

		user_limit : (callback)->
			# limit for each plan
			plan_limit = [10, 25, 50]
			self = @

			# test if this can create more user
			can_create_user = (current_type)->
				current_type = Number(current_type)
				if current_type is 3
					return true
				else
					limit = plan_limit[current_type]
					return Nimbus.keys(foundry._user_list).length < limit
			
			@get_user_plan((user)->
				if user
					order = user.order
					self.user_plan = order.type
					if order.status is 0
						self.user_plan = 0
				else
					self.user_plan = 0
				result = can_create_user(self.user_plan)

				callback(result) if callback
			)
				
			return

		alert_for_upgrade : (msg)->
			if !msg
				msg = "<div style='padding:20px 10px;'>Your user amount has exceeded the plan your've purchased. You need to upgrade to a higher plan.</div>";
			bootbox.dialog(
				message : msg
				title : 'Upgrade Needed'
				className : 'nimbus_confirm_modal'
				buttons: 
					success : 
						label: "Upgrade"
						className : 'btn-success'
						callback : (evt)->
							window.open('http://getforum.us/pricing.html')
					cancel : 
						className : 'btn-danger'
						callback : (evt)->
							console.log 'go away'

			)
	)

inject_controller = ()->

	angular.module('foundry').controller('UserListController', ['$scope', '$rootScope', '$parse', ($scope, $rootScope, $parse)->
		# use model and data
		user_model = foundry.load('user')
		$scope.users = foundry._user_list

		###
			basic settings
		###
		$rootScope.breadcum = 'Users'
		$rootScope.shortcut_name = 'Add User'

		current_user = foundry._current_user
		$scope.user_permission = 'Viewer'
		update_current_user_permission = ()->
			current_user_in_model = foundry._models.User.findByAttribute('pid',current_user.id)
			if current_user_in_model
				$scope.user_permission = current_user_in_model.role
		update_current_user_permission()

		$scope.add_shortcut = ()->
			$scope.form_mode = 'create'
			$('.form').modal()
			return

		$scope.form_mode = 'create'
		$scope.usermodel = 
			fields: 
				email : 
					type : 'input'
					label : 'Email'
				role :
					type : 'select'
					label : 'Role'
					options : 
						Admin : 'Admin'
						Viewer : 'Viewer'
			create : 'submit()'
			update : 'update()'
		$scope.userEditModel = 
			fields: 
				role :
					type : 'select'
					label : 'Role'
					options : 
						Admin : 'Admin'
						Viewer : 'Viewer'
			create : 'submit()'
			update : 'update()'
		$scope.user_data = 
			name : ''
			email : ''


		###
			user CURD
		###
		$scope.edit_user = (id)->
			$scope.form_mode = 'edit'
			# extend user for furthure user 
			$scope.user_data = angular.copy($scope.users[id])
			$scope.user_data.role = $scope.user_data.roleName

			$('.update_form').modal()
			return
			
		$scope.update = ()->
			user_model.save_user($scope.user_data.id, $scope.user_data)
			update_current_user_permission()
			$('.modal').modal('hide')
			$scope.user_data = {}
			return

		$scope.del_user = (id)->
			user_model.del_user($scope.users[id])

			delete foundry._user_list[id]


		$scope.creating_user = false
		$scope.submit = ()->
			return if $scope.creating_user
			$scope.creating_user = true

			reset = ()->
				$scope.user_data = {}
				$('.form').modal('hide')
				$('.create_button').removeClass('disabled')
				$scope.creating_user = false

			$('.create_button').addClass('disabled')
			user_model.add_user($scope.user_data, ()->
				reset()
			)
				
			return
		$scope.user_info = {}
		$scope.show_user = (id)->
			user = $scope.users[id]
			$scope.user_info = 
				'name' : user.name
				'email' : user.email
			$('.userinfo').modal()
			return

		$scope.is_owner = (user)->
			user.id is foundry._current_owner.id
			
		$scope.clear = ()->
			$('.modal').modal('hide')
			$scope.user_data = {}

			return
		return
	])
