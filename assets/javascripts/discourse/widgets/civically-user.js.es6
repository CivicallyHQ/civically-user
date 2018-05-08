import { createWidget } from 'discourse/widgets/widget';
import { createAppWidget } from 'discourse/plugins/civically-app/discourse/widgets/app-widget';
import RawHtml from 'discourse/widgets/raw-html';
import DiscourseURL from 'discourse/lib/url';
import { iconNode } from 'discourse-common/lib/icon-library';
import { cookAsync } from 'discourse/lib/text';
import { ajax } from 'discourse/lib/ajax';
import { buildTitle, clearUnreadList } from 'discourse/plugins/civically-navigation/discourse/lib/utilities';
import { h } from 'virtual-dom';

createWidget('checklist-item', {
  tagName: 'li',
  buildKey: (attrs) => `${attrs.item.id}-checklist-item`,

  buildClasses(attrs) {
    let classes = 'checklist-item';

    if (attrs.next) {
      classes += ' next';
    }

    if (!attrs.item.active) {
      classes += ' inactive';
    }

    if (attrs.item.checked) {
      classes += ' checked';
    }

    return classes;
  },

  defaultState(attrs) {
    return {
      showDetail: false,
      checked: attrs.item.checked,
      checkable: attrs.item.checkable,
      active: attrs.item.active,
      cookedDetail: null
    };
  },

  html(attrs, state) {
    const icon = state && state.checked ? 'check' : 'arrow-right';
    let className = 'check-toggle';
    let contents = [];

    if (state.cookedDetail === null) {
      cookAsync(attrs.item.detail).then((cooked) => {
        state.cookedDetail = cooked;
      });
    }

    if (state && state.checkable) {
      className += ' checkable';

      contents.push(this.attach('button', {
        icon,
        className,
        action: 'toggleCheck',
      }));
    } else {
      contents.push(h('div.check-toggle', iconNode(icon, { className })));
    }

    let rightContents = [
      this.attach('button', {
        className: 'check-title',
        contents: h('span', attrs.item.title),
        action: 'showDetail'
      })
    ];

    if (state && state.showDetail) {
      rightContents.push(h('div.check-detail',
        new RawHtml({ html: `${state.cookedDetail}` })
      ));
    }

    contents.push(h('div.right-contents', rightContents));

    return contents;
  },

  showDetail() {
    if (!this.attrs.item.active) return;
    this.state.showDetail = !this.state.showDetail;
    this.scheduleRerender();
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

export default createAppWidget('civically-user', {
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

    contents.push(h(`div.${classes}`, widgetListContents));

    return contents;
  },

  showList(type) {
    this.state.loading = true;
    this.state.currentListType = type;
    this.scheduleRerender();
  }
});
