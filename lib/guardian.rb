## TO DO: Move class_evals to an extension

require_dependency 'guardian'
Guardian.class_eval do
  def can_invite_to_forum?(groups = nil)
    authenticated? &&
    (SiteSetting.max_invites_per_day.to_i > 0 || is_staff?) &&
    !SiteSetting.enable_sso &&
    SiteSetting.enable_local_logins &&
    (
      (!SiteSetting.must_approve_users? && @user.has_trust_level?(TrustLevel[1])) ||
      is_staff?
    ) &&
    (groups.blank? || is_admin?)
  end

  def can_invite_to?(object, groups = nil)
    return false unless authenticated?
    return true if is_admin?
    return false unless SiteSetting.enable_private_messages?
    return false if (SiteSetting.max_invites_per_day.to_i == 0 && !is_staff?)
    return false unless can_see?(object)
    return false if groups.present?

    if object.is_a?(Topic) && object.category
      if object.category.groups.any?
        return true if object.category.groups.all? { |g| can_edit_group?(g) }
      end
    end

    user.has_trust_level?(TrustLevel[1])
  end

  def can_delete_user?(user)
    return false if user.nil? || user.admin?
    if is_me?(user)
      user.post_count <= 1
    else
      is_admin? && (user.first_post_created_at.nil? || user.first_post_created_at > SiteSetting.delete_user_max_post_age.to_i.days.ago)
    end
  end

  def can_delete_all_posts?(user)
    is_admin? &&
    user &&
    !user.admin? &&
    (user.first_post_created_at.nil? || user.first_post_created_at >= SiteSetting.delete_user_max_post_age.days.ago) &&
    user.post_count <= SiteSetting.delete_all_posts_max.to_i
  end

  def can_change_trust_level?(user)
    user && is_admin?
  end
end
