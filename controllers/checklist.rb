class CivicallyChecklist::ChecklistController < ::ApplicationController
  before_action :can_use_list

  def list
    user = User.find_by(username: params[:username])
    list = CivicallyChecklist::Checklist.get_list_visible(user)
    render_json_dump(list.take(5))
  end

  def update
    params.require(:updates)

    user = User.find_by(username: update_params[:username])

    result = CivicallyChecklist::Checklist.update_item(user, update_params[:item_id], update_params[:updates].to_h)

    if result
      render json: success_json.merge(updates: result)
    else
      render json: failed_json
    end
  end

  def add
    params.require(:item)

    user = User.find_by(username: add_params[:username])

    result = CivicallyChecklist::Checklist.add_item(user, add_params[:item].to_h)

    if result
      render json: success_json.merge(item: result)
    else
      render json: failed_json
    end
  end

  private

  def can_use_list
    params.require(:username)

    if !current_user.staff? && current_user.username != params[:username]
      raise Discourse::InvalidAccess.new
    end
  end

  def update_params
    params.permit(:username, :item_id, updates: [:id, :checked, :hidden])
  end

  def add_params
    params.permit(:username, item: [:title, :detail])
  end
end
