export default {
  resource: 'admin',
  map() {
    this.route('adminChecklists', { path: '/checklists', resetNamespace: true });
  }
};
