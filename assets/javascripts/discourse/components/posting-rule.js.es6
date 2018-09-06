import { default as computed } from 'ember-addons/ember-computed-decorators';
import { cookAsync } from 'discourse/lib/text';

export default Ember.Component.extend({
  tagName: 'li',
  classNames: 'posting-rule',

  init() {
    this._super();
    const rule = this.get('rule');
    let description = I18n.t(`user.rules.${rule}.description`);
    cookAsync(description).then((cooked) => {
      this.set('description', cooked);
    });
  },

  @computed('rule')
  title(rule) {
    return I18n.t(`user.rules.${rule}.title`);
  },

  click() {
    this.toggleProperty('showDescription');
  }
});
