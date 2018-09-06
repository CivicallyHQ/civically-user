import { ajax } from 'discourse/lib/ajax';
import { popupAjaxError } from 'discourse/lib/ajax-error';
import { cookAsync } from 'discourse/lib/text';

export default Ember.Component.extend({
  classNames: 'posting-rules app-widget-container',
  rules: ['identification', 'advice', 'adverts', 'compliance'],

  init() {
    this._super();
    const acceptanceRaw = I18n.t('user.rules.accepted_message');
    cookAsync(acceptanceRaw).then((cooked) => {
      this.set('acceptanceMessage', cooked);
    });
  },

  click() {
    if (this.get('showAcceptanceMessage')) {
      this.set('showAcceptanceMessage', false);
    }
  },

  actions: {
    acceptRules() {
      this.set('accepting', true);

      const username = this.get('currentUser.username');

      ajax(`/c-user/${username}/accept-rules`, {
        type: "PUT"
      }).catch(popupAjaxError).then((result) => {
        if (result.success) {
          Discourse.User.currentProp('accepted_rules', true);
          this.set('showAcceptanceMessage', true);
        }
      }).finally(() => {
        this.set('accepting', false);
      });
    },

    hideRules() {
      this.set('hiding', true);

      const username = this.get('currentUser.username');

      ajax(`/c-user/${username}/toggle-rules`, {
        type: "PUT",
        data: {
          state: true
        }
      }).catch(popupAjaxError).then((result) => {
        if (result.success) {
          Discourse.User.currentProp('hide_rules', true);
        }
      }).finally(() => {
        this.set('hiding', false);
      });
    }
  }
});
