import { default as computed } from 'ember-addons/ember-computed-decorators';

export default Ember.Component.extend({
  classNames: 'user-prompt',

  @computed('key', 'keyParams')
  text(key, keyParams) {
    return I18n.t(key, keyParams);
  }
});
