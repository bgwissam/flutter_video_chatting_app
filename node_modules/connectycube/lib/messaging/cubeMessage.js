const Config = require('../cubeConfig')
const Utils = require('../cubeInternalUtils')

const MESSAGES_API_URL = Config.urls.chat + '/Message'

class ChatMessagesService {
  constructor(proxy) {
    this.proxy = proxy
  }

  list(params) {
    const ajaxParams = {
      url: Utils.getUrl(MESSAGES_API_URL),
      data: params
    }

    return this.proxy.ajax(ajaxParams)
  }

  create(params) {
    const ajaxParams = {
      url: Utils.getUrl(MESSAGES_API_URL),
      type: 'POST',
      data: params
    }

    return this.proxy.ajax(ajaxParams)
  }

  update(id, params) {
    const ajaxParams = {
      type: 'PUT',
      dataType: 'text',
      url: Utils.getUrl(MESSAGES_API_URL, id),
      data: params
    }

    return this.proxy.ajax(ajaxParams)
  }

  delete(id, params = {}) {
    const ajaxParams = {
      url: Utils.getUrl(MESSAGES_API_URL, id),
      type: 'DELETE',
      dataType: 'text'
    }

    if (params) {
      ajaxParams.data = params
    }

    return this.proxy.ajax(ajaxParams)
  }

  unreadCount(params) {
    if (params && params.chat_dialog_ids && Utils.isArray(params.chat_dialog_ids)) {
      params.chat_dialog_ids = params.chat_dialog_ids.join(', ')
    }

    const ajaxParams = {
      url: Utils.getUrl(MESSAGES_API_URL + '/unread'),
      data: params
    }

    return this.proxy.ajax(ajaxParams)
  }
}

module.exports = ChatMessagesService
