module Jobs
  class BulkUnreadListsUpdate < Jobs::Base
    def execute(args)
      users = User.where("id in (
        SELECT user_id FROM user_custom_fields WHERE name = 'place_category_id' AND value = ?
      )", args['place_category_id']).to_a

      users.each do |user|
        if args['add_lists']
          args['add_lists'].each do |list|
            CivicallyUser::User.add_unread_list(user, list)
          end
        end
      end
    end
  end
end
