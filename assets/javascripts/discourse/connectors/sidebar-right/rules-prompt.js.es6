const showRules = function(path, user) {
  return !user.hide_rules && path.indexOf('place') === -1;
};

export default {
  setupComponent(attrs, component) {
    component.set('showRules', showRules(attrs.path, component.get('currentUser')));
    component.addObserver('path', function() {
      component.set('showRules', showRules(component.get('path'), component.get('currentUser')));
    });
  }
};
