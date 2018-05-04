import { default as computed, observes, on } from 'ember-addons/ember-computed-decorators';
import { ajax } from 'discourse/lib/ajax';
import { popupAjaxError } from 'discourse/lib/ajax-error';

export default Ember.Controller.extend({
  targetPlace: true,
  targetUsers: false,
  _target: 'place',
  showSave: false,
  saveResult: '',
  type: null,
  updateTarget: null,
  hasType: Ember.computed.notEmpty('type'),
  showUpdate: Ember.computed.equal('type', 'update'),
  showAdd: Ember.computed.equal('type', 'add'),
  showRemove: Ember.computed.equal('type', 'remove'),
  booleanOptions: [
    { id: true, name: "True" },
    { id: false, name: "False" }
  ],

  @computed('targetValid', 'gettingItems')
  actionDisabled(targetValid, gettingItems) {
    return !targetValid || gettingItems;
  },

  @observes('targetUsers', 'targetPlace')
  toggleTargets(component, property) {
    if (this.get(property)) {
      let target = property.split('target')[1];
      let inverse = target === 'Place' ? 'Users' : 'Place';
      this.set(`target${inverse}`, false);
      this.set('_target', target.toLowerCase());
    }
  },

  @computed('placeCategoryId', 'usernames', '_target')
  targetValid(placeCategoryId, usernames, target) {
    if (target === 'place') return placeCategoryId;
    if (target === 'users') return usernames;
  },

  getItems() {
    let data = {
      target: this.buildTarget()
    }

    this.set('gettingItems', true);

    ajax('/admin/checklists/items', {
      type: 'GET',
      data
    }).then((result) => {
      if (result.item_ids) {
        this.setProperties({
          itemIds: result.item_ids,
          hasItems: true
        });
      }
    }).finally(() => {
      this.set('gettingItems', false);
    });
  },

  @computed('id', 'active', 'checkable', 'checked', 'title', 'detail')
  updateValid(id, active, checkable, checked, title, detail) {
    return id &&
           (_.intersection([active, checkable, checked], [true, false]).length ||
           (title || detail));
  },

  @computed('id', 'active', 'checkable', 'checked', 'title', 'detail')
  addValid(id, active, checkable, checked, title, detail) {
    return id &&
           [active, checkable, checked].indexOf(undefined) === -1 &&
           title &&
           detail;
  },

  removeValid: Ember.computed.notEmpty('id'),

  @computed('type')
  saveLabel(type) {
    return `admin.checklist.${type}.save`;
  },

  @computed('targetValid', 'type', 'addValid', 'updateValid', 'removeValid', 'saving')
  saveDisabled(targetValid, type, addValid, updateValid, removeValid, saving) {
     if (!targetValid || saving) return true;
     if (type === 'add') return !addValid;
     if (type === 'update') return !updateValid;
     if (type === 'remove') return !removeValid;
  },

  buildTarget() {
    let data = {};

    const target = this.get('_target');
    if (target === 'place') data['place_category_id'] = this.get('placeCategoryId');
    if (target === 'users') data['usernames'] = this.get('usernames');

    return data;
  },

  buildItem() {
    let item = {};

    item['id'] = this.get('id');

    const active = this.get('active');
    const checkable = this.get('checkable');
    const checked = this.get('checked');
    const title = this.get('title');
    const detail = this.get('detail');

    if (active !== undefined && active !== null) item['active'] = active;
    if (checkable !== undefined && checkable !== null) item['checkable'] = checkable;
    if (checked !== undefined && checked !== null) item['checked'] = checked;
    if (title) item['title'] = title;
    if (detail) item['detail'] = detail;

    return item;
  },

  @computed('saveResult')
  hasSavedResult(saveResult) {
    return saveResult.length > 0;
  },

  @computed('saveResult')
  savedIcon(saveResult) {
    return saveResult === 'saved' ? 'tick' : 'times';
  },

  save(type) {
    if (!this.get(`${type}Valid`)) return;

    let data = {
      target: this.buildTarget()
    }

    if (type === 'remove') {
      data['item_id'] = this.get('id');
    } else {
      data['item'] = this.buildItem();

      if (type === 'add') {
        let index = this.get('index');
        if (index) data['index'] = index;
      }
    }

    this.set('saving', true);

    ajax(`/admin/checklists/${type}`, {
      type: "POST",
      data
    }).then((result) => {
      let saveResult = result.success ? 'saved' : 'failed';

      this.set('saveResult', saveResult);

      let self = this;
      Ember.run.later((() => {
        if (self._state !== 'destroying') {
          self.set('saveResult', '');
        }
      }), 5000);
    }).catch(popupAjaxError).finally(() => {
      this.set('saving', false);
    })
  },

  actions: {
    updateItem() {
      this.setProperties({
        type: 'update',
        showSave: true
      })

      this.getItems();
    },

    addItem() {
      this.setProperties({
        type: 'add',
        showSave: true
      });
    },

    removeItem() {
      this.setProperties({
        type: 'remove',
        showSave: true
      })

      this.getItems();
    },

    save() {
      const type = this.get('type');
      this.save(type);
    }
  }
})
