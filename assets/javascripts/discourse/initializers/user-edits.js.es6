import InviteController from 'discourse/controllers/invite';
import { emailValid } from 'discourse/lib/utilities';
import { default as computed, observes } from 'ember-addons/ember-computed-decorators';
import { withPluginApi } from 'discourse/lib/plugin-api';

export default {
  name: 'civically-user-edits',
  initialize(container) {
    const currentUser = container.lookup('current-user:main');

    withPluginApi('0.8.12', api => {
      if (currentUser && currentUser.staff) {
        const AdminUser = requirejs('admin/models/admin-user').default;

        api.modifyClass('route:admin-users-list-show', {
          model(params) {
            this.userFilter = params.filter;
            let opts = {};
            const user = this.currentUser;
            if (!user.admin) {
              opts['custom_fields'] = {
                place_category_id: user.moderator_category_id
              };
            }
            return AdminUser.findAll(params.filter, opts);
          },

          setupController: function(controller, model) {
            const isAdmin = this.currentUser.get('admin');
            controller.setProperties({
              model: model,
              query: this.userFilter,
              showEmails: !isAdmin,
              refreshing: false,
            });
          }
        });

        api.modifyClass('controller:admin-users-list-show', {
          @observes('order', 'ascending')
          _refreshUsers: function() {
            this.set('refreshing', true);
            let opts = {
              filter: this.get('listFilter'),
              order: this.get('order'),
              ascending: this.get('ascending')
            };

            const user = this.currentUser;
            if (user.admin) {
              opts['show_emails'] = this.get('showEmails');
            } else {
              opts['custom_fields'] = {
                place_category_id: user.moderator_category_id
              };
            }

            AdminUser.findAll(this.get('query'), opts).then( (result) => {
              this.set('model', result);
            }).finally( () => {
              this.set('refreshing', false);
            });
          },
        });
      }

      api.modifyClass('controller:invites-show', {
        @computed()
        disclaimer() {
          return I18n.t("invite.disclaimer", {
            tos_link: "/tos",
            privacy_link: "/privacy"
          });
        }
      })
    });
  }
};
