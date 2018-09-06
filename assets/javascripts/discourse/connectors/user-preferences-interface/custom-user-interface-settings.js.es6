import { cookAsync } from 'discourse/lib/text';

export default {
  setupComponent(attrs, component) {
    if (attrs.model.accepted_rules_at) {
      let dateTime = moment(attrs.model.accepted_rules_at)
        .format("dddd, MMMM Do YYYY, h:mm:ss a");
      let raw = I18n.t('user.rules.accepted_at', { dateTime });
      cookAsync(raw).then((cooked) => component.set('acceptedMessage', cooked));
    }
  }
};
