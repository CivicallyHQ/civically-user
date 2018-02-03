module Jobs
  class BulkChecklistUpdate < Jobs::Base
    def execute(args)
      users = User.where(id: args['user_ids'])
      users.each do |user|
        if args['checked']
          CivicallyChecklist::Checklist.update_item(user, args['checked']['id'], checked: args['checked']['state'])
        end
        if args['active']
          CivicallyChecklist::Checklist.update_item(user, args['active']['id'], active: args['active']['state'])
        end
      end
    end
  end
end
