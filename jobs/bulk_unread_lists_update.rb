module Jobs
  class BulkUnreadListsUpdate < Jobs::Base
    def execute(args)
      place = CivicallyPlace::Place.find(args['category_id'])

      users = User.where("id in (
        SELECT user_id FROM user_custom_fields WHERE name = '#{place.place_type}_category_id' AND value = ?
      )", args['category_id'].to_s).to_a

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
