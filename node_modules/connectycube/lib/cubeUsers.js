const config = require('./cubeConfig')
const Utils = require('./cubeInternalUtils')

class UsersService {
  constructor(proxy) {
    this.proxy = proxy
  }

  get(params) {
    let url
    const filters = []
    let item

    if (params.order) {
      params.order = generateOrder(params.order)
    }

    if (params && params.filter) {
      if (Utils.isArray(params.filter)) {
        params.filter.forEach(function (el) {
          item = generateFilter(el)
          filters.push(item)
        })
      } else {
        item = generateFilter(params.filter)
        filters.push(item)
      }
      params.filter = filters
    }

    if (typeof params === 'number') {
      url = params
      params = {}
    } else {
      if (params.login) {
        url = 'by_login'
      } else if (params.full_name) {
        url = 'by_full_name'
      } else if (params.facebook_id) {
        url = 'by_facebook_id'
      } else if (params.twitter_id) {
        url = 'by_twitter_id'
      } else if (params.phone) {
        url = 'phone'
      } else if (params.email) {
        url = 'by_email'
      } else if (params.tags) {
        url = 'by_tags'
      } else if (params.external) {
        url = 'external/' + params.external
        params = {}
      }
    }

    const ajaxParams = {
      type: 'GET',
      url: Utils.getUrl(config.urls.users, url),
      data: params
    }

    return this.proxy.ajax(ajaxParams)
  }

  signup(params) {
    const ajaxParams = {
      type: 'POST',
      url: Utils.getUrl(config.urls.users),
      data: {
        user: params
      }
    }

    return this.proxy.ajax(ajaxParams)
  }

  update(params) {
    const ajaxParams = {
      type: 'PUT',
      url: Utils.getUrl(config.urls.users, this.proxy.getCurrentUserId()),
      data: { user: params }
    }

    return this.proxy.ajax(ajaxParams)
  }

  delete() {
    const ajaxParams = {
      type: 'DELETE',
      url: Utils.getUrl(config.urls.users, this.proxy.getCurrentUserId()),
      dataType: 'text'
    }

    return this.proxy.ajax(ajaxParams)
  }

  resetPassword(email) {
    const ajaxParams = {
      type: 'GET',
      url: Utils.getUrl(config.urls.users + '/password/reset'),
      data: {
        email: email
      },
      dataType: 'text'
    }

    return this.proxy.ajax(ajaxParams)
  }
}

module.exports = UsersService

const DATE_FIELDS = ['created_at', 'updated_at', 'last_request_at']
const NUMBER_FIELDS = ['id', 'external_user_id']

function generateFilter(obj) {
  let type = obj.field in DATE_FIELDS ? 'date' : typeof obj.value

  if (Utils.isArray(obj.value)) {
    if (type === 'object') {
      type = typeof obj.value[0]
    }
    obj.value = obj.value.toString()
  }

  return [type, obj.field, obj.param, obj.value].join(' ')
}

function generateOrder(obj) {
  const type =
    obj.field in DATE_FIELDS
      ? 'date'
      : obj.field in NUMBER_FIELDS
        ? 'number'
        : 'string'
  return [obj.sort, type, obj.field].join(' ')
}
