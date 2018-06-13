import { default as computed } from 'ember-addons/ember-computed-decorators';
import { iconHTML } from 'discourse-common/lib/icon-library';
import { emojiUnescape } from 'discourse/lib/text';
import showModal from "discourse/lib/show-modal";
import DiscourseURL from 'discourse/lib/url';

export default Ember.Component.extend({
  classNameBindings: [':user-prompt', 'button:btn'],
  hasImage: Ember.computed.or('emoji', 'icon'),
  button: Ember.computed.or('action', 'modal', 'routeTo'),
  modalModel: null,

  @computed('emoji', 'icon')
  image(emoji, icon) {
    let image;

    if (emoji) {
      image = emojiUnescape(`:${emoji}:`);
    } else if (icon) {
      image = iconHTML(icon);
    }

    return new Handlebars.SafeString(image);
  },

  @computed('key', 'keyParams', 'rawText')
  text(key, keyParams, rawText) {
    return rawText ? rawText : I18n.t(key, keyParams);
  },

  click() {
    const action = this.get('action');
    const modal = this.get('modal');
    const routeTo = this.get('routeTo');
    if (action) this.sendAction('action');
    if (modal) this.openModal(modal);
    if (routeTo) DiscourseURL.routeTo(routeTo);
  },

  openModal(modal) {
    showModal(modal, {
      model: this.get('modalModel')
    });
  }
});
