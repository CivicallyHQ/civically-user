class ::User
  def unread_lists
    if custom_fields['unread_lists']
      [*custom_fields['unread_lists']]
    else
      []
    end
  end
end

module ::CivicallyUser
  class Engine < ::Rails::Engine
    engine_name "civically_user"
    isolate_namespace CivicallyUser
  end
end

CivicallyUser::Engine.routes.draw do
  delete ':user/unread-list' => 'user#clear_unread_list'
end

Discourse::Application.routes.append do
  mount ::CivicallyUser::Engine, at: 'c-user'
end

class CivicallyUser::User
  def self.add_unread_list(user, list)
    unread_lists = user.unread_lists
    user.custom_fields['unread_lists'] = unread_lists.push(list) if unread_lists.exclude?(list)
    user.save_custom_fields(true)
  end

  def self.remove_unread_list(user, list)
    unread_lists = user.unread_lists
    user.custom_fields['unread_lists'] = unread_lists - [list]
    user.save_custom_fields(true)
  end
end

class CivicallyUser::UserController < ::ApplicationController
  def clear_unread_list
    params.require(:user)
    params.require(:list)

    result = CivicallyUser::User.remove_unread_list(current_user, params[:list])

    if result
      render json: success_json
    else
      render json: failed_json
    end
  end
end
