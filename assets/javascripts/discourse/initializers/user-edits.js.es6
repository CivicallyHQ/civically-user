import InviteController from 'discourse/controllers/invite';
import { emailValid } from 'discourse/lib/utilities';
import { default as computed, observes } from 'ember-addons/ember-computed-decorators';
import { withPluginApi } from 'discourse/lib/plugin-api';

export default {
  name: 'civically-user-edits',
  initialize(container) {
    const currentUser = container.lookup('current-user:main');

    if (currentUser && currentUser.staff) {
      const AdminUser = requirejs('admin/models/admin-user').default;

      withPluginApi('0.8.12', api => {
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
      });
    }

    // overriding method to pass title to translations when inviting new users from a topic.
    InviteController.reopen({
      @computed('isMessage', 'invitingToTopic', 'emailOrUsername', 'isPrivateTopic', 'isAdmin', 'canInviteViaEmail')
      inviteInstructions(isMessage, invitingToTopic, emailOrUsername, isPrivateTopic, isAdmin, canInviteViaEmail) {
        if (!canInviteViaEmail) {
          // can't invite via email, only existing users
          return I18n.t('topic.invite_reply.sso_enabled');
        } else if (isMessage) {
          // inviting to a message
          return I18n.t('topic.invite_private.email_or_username');
        } else if (invitingToTopic) {
          // inviting to a private/public topic
          if (isPrivateTopic && !isAdmin) {
            // inviting to a private topic and is not admin
            return I18n.t('topic.invite_reply.to_username', {topicTitle: this.get('model.title')});
          } else {
            // when inviting to a topic, display instructions based on provided entity
            if (Ember.isEmpty(emailOrUsername)) {
              return I18n.t('topic.invite_reply.to_topic_blank', {topicTitle: this.get('model.title')});
            } else if (emailValid(emailOrUsername)) {
              this.set("inviteIcon", "envelope");
              return I18n.t('topic.invite_reply.to_topic_email', {topicTitle: this.get('model.title')});
            } else {
              this.set("inviteIcon", "hand-o-right");
              return I18n.t('topic.invite_reply.to_topic_username', {topicTitle: this.get('model.title')});
            }
          }
        } else {
          // inviting to forum
          return I18n.t('topic.invite_reply.to_forum');
        }
      }
    });
  }
};
