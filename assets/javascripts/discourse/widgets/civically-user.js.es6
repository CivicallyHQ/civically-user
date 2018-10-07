import { createWidget } from 'discourse/widgets/widget';
import RawHtml from 'discourse/widgets/raw-html';
import DiscourseURL from 'discourse/lib/url';
import { iconNode } from 'discourse-common/lib/icon-library';
import { cookAsync } from 'discourse/lib/text';
import { ajax } from 'discourse/lib/ajax';
import popupAjaxError from 'discourse/lib/ajax-error';

import { h } from 'virtual-dom';

createWidget('checklist-item', {
  tagName: 'li',
  buildKey: (attrs) => `${attrs.item.id}-checklist-item`,

  buildClasses(attrs) {
    let classes = 'checklist-item';

    if (attrs.next) {
      classes += ' next';
    }

    if (!this.state.active) {
      classes += ' inactive';
    }

    if (this.state.checked) {
      classes += ' checked';
    }

    if (this.state.hidden) {
      classes += ' hidden';
    }

    return classes;
  },

  defaultState(attrs) {
    return {
      showDetail: false,
      checked: attrs.item.checked,
      checkable: attrs.item.checkable,
      active: attrs.item.active,
      hidden: attrs.item.hidden,
      hideable: attrs.item.hideable,
      cookedDetail: null
    };
  },

  html(attrs, state) {
    const item = attrs.item;

    console.log('running item');

    if (state.cookedDetail === null) {
      cookAsync(item.detail).then((cooked) => {
        state.cookedDetail = cooked;
      });
    }

    let contents = [];

    let checkIcon = state && state.checked ? 'check' : 'arrow-right';
    let checkClass = 'check-toggle';

    if (state.togglingCheck) {
      contents.push(h('div.check-toggle.spinner.tiny'));
    } else if (state && state.checkable) {
      checkClass += ' checkable';

      contents.push(this.attach('button', {
        icon: checkIcon,
        className: checkClass,
        action: 'toggleCheck',
      }));
    } else {
      contents.push(h('div.check-toggle', iconNode(checkIcon, { className: checkClass })));
    }

    let itemBody = [
      this.attach('button', {
        className: 'check-title',
        contents: h('span', attrs.item.title),
        action: 'showDetail'
      })
    ];

    if (state && state.showDetail) {
      itemBody.push(h('div.check-detail',
        new RawHtml({ html: `${state.cookedDetail}` })
      ));
    }

    contents.push(h('div.item-body', itemBody));

    if (state.hideable) {
      if (state.togglingHidden) {
        contents.push(h('div.hidden-toggle.spinner.tiny'));
      } else {
        contents.push(this.attach('button', {
          icon: 'eye-slash',
          className: 'hidden-toggle',
          action: 'toggleHidden',
        }));
      }
    }

    return contents;
  },

  showDetail() {
    if (!this.attrs.item.active) return;
    this.state.showDetail = !this.state.showDetail;
    this.scheduleRerender();
  },

  toggleCheck() {
    this.state.togglingCheck = true;
    this.updateItem({
      checked: !this.state.checked
    }).then(() => {
      this.state.togglingCheck = false;
      this.scheduleRerender();
    });
  },

  toggleHidden() {
    this.state.togglingHidden = true;
    this.updateItem({
      hidden: !this.state.hidden
    }).then(() => {
      this.state.togglingHidden = false;
      this.scheduleRerender();
    });
  },

  updateItem(updates) {
    const username = this.currentUser.username;
    const itemId = this.attrs.item.id;

    return ajax(`/checklist/${username}/${itemId}/update`, {
      type: 'PUT',
      data: { updates }
    }).then((result) => {
      if (result.success) {
        Object.keys(result.updates).forEach((k) => {
          this.state[k] = result.updates[k];
        });
      }
    }).catch(popupAjaxError);
  }
});

createWidget('bookmark-item', {
  tagName: 'li',

  html(attrs) {
    const topic = attrs.topic;
    const title = topic.get('fancyTitle');
    let contents = [ h('span', title) ];

    const unseen = topic.get('unseen');
    if (unseen) {
      contents.push(h('a.badge.badge-notification.new-topic'));
    }

    return contents;
  },

  click() {
    const url = this.attrs.topic.get('url');
    DiscourseURL.routeTo(url);
  }
});

// User Widget
const navigationUtilitiesPath = 'discourse/plugins/civically-navigation/discourse/lib/utilities';
const appWidgetPath = 'discourse/plugins/civically-app/discourse/widgets/app-widget';
let userWidget = {};

if (requirejs.entries[navigationUtilitiesPath] && requirejs.entries[appWidgetPath]) {
  const buildTitle = requirejs(navigationUtilitiesPath).buildTitle;
  const clearUnreadList = requirejs(navigationUtilitiesPath).clearUnreadList;
  const createAppWidget = requirejs(appWidgetPath).createAppWidget;

  const userWidgetParams = {
    defaultState() {
      return {
        currentListType: 'checklist',
        checklist: [],
        bookmarks: [],
        loading: true
      };
    },

    getChecklist() {
      const username = this.currentUser.username;
      ajax(`/checklist/${username}`).then((items) => {
        this.state.checklist = items || [];
        this.state.loading = false;
        this.scheduleRerender();
      });
    },

    getBookmarks() {
      this.store.findFiltered('topicList', {
        filter: 'bookmarks'
      }).then((result) => {
        this.state.bookmarks = result.topics.slice(0,5) || [];
        this.state.loading = false;
        this.scheduleRerender();
      });
    },

    buildChecklist() {
      let next = false;
      return h('ul', this.state.checklist.map((item) => {
        let itemAttrs = { item };
        if (!item.checked && next === false) {
          next = true;
          itemAttrs['next'] = next;
        }
        return this.attach('checklist-item', itemAttrs);
      }));
    },

    buildBookmarks() {
      const bookmarks = this.state.bookmarks;
      let list = [ h('div.no-items', I18n.t('app.civically_site.list.none')) ];

      if (bookmarks.length > 0) {
        list = bookmarks.map((topic) => {
          return this.attach('bookmark-item', { topic });
        });
      }

      return h('ul', list);
    },

    contents() {
      const loading = this.state.loading;
      const currentListType = this.state.currentListType;
      const user = this.currentUser;

      let contents = [
        h('div.widget-multi-title', [
          buildTitle(this, 'user', 'checklist'),
          buildTitle(this, 'user', 'bookmarks')
        ])
      ];

      let listContents = [];

      if (loading) {
        if (currentListType === 'checklist') {
          this.getChecklist();
        } else {
          this.getBookmarks();
        }
        listContents.push(h('div.spinner.small'));
      } else {
        clearUnreadList(this, currentListType);

        if (currentListType === 'checklist') {
          listContents.push(this.buildChecklist());
        } else {
          listContents.push(this.buildBookmarks());
        }
      }

      console.log('passed');

      let classes = 'widget-list';

      if (currentListType === 'checklist') {
        classes += '.no-borders';
      }

      let widgetListContents = [listContents];

      if (currentListType === 'bookmarks') {
        widgetListContents.push(h('div.widget-list-controls', this.attach('link', {
          className: 'p-link',
          href: `/u/${user.username}/activity/bookmarks`,
          label: 'more'
        })));
      }

      if (user.checklist.can_add) {
        if (currentListType === 'checklist') {
          if (this.state.savingItem) {
            widgetListContents.push(h('div.spinner.tiny'));
          } else if (this.state.addItem) {
            widgetListContents.push(h('div.add-item', [
              h('div.inputs', [
                h('input.title', {
                  placeholder: I18n.t('user.checklist.item.title')
                }),
                h('textarea.detail', {
                  placeholder: I18n.t('user.checklist.item.detail')
                })
              ]),
              this.attach('button', {
                icon: 'check',
                action: 'saveItem',
                className: 'save-item btn-primary btn-small'
              }),
              this.attach('button', {
                icon: 'times',
                action: 'closeAdd',
                className: 'close-add btn-small'
              })
            ]));
          } else {
            widgetListContents.push(h('div.widget-list-controls', this.attach('link', {
              className: 'p-link',
              label: 'user.checklist.add',
              action: 'addItem'
            })));
          }
        }
      }

      contents.push(h(`div.${classes}`, widgetListContents));

      return contents;
    },

    showList(type) {
      this.state.loading = true;
      this.state.currentListType = type;
      this.scheduleRerender();
    },

    addItem() {
      this.state.addItem = true;
      this.scheduleRerender();
    },

    closeAdd() {
      this.state.addItem = false;
      this.scheduleRerender();
    },

    saveItem() {
      const username = this.currentUser.username;
      this.state.addItem = false;
      this.state.savingItem = true;

      let item = {
        title: $('.civically-user .add-item input.title').val(),
        detail: $('.civically-user .add-item textarea.detail').val()
      };

      ajax(`/checklist/${username}/add`, {
        type: 'PUT',
        data: {
          item
        }
      }).then((result) => {
        if (result.success) {
          let existing = this.state.checklist;
          existing.push(result.item);
          this.state.checklist = existing;
        }
      }).catch(popupAjaxError).finally(() => {
        this.state.savingItem = false;
        this.scheduleRerender();
      });

      this.scheduleRerender();
    }
  };

  userWidget = createAppWidget('civically-user', userWidgetParams);
}

export default userWidget;
