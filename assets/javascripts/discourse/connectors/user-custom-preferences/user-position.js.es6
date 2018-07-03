export default {
  setupComponent(attrs, component) {
    Ember.run.scheduleOnce('afterRender', () => {
      const $bioInput = $('.control-group.pref-bio');
      component.$('.control-group').insertAfter($bioInput);
    });
  }
};
