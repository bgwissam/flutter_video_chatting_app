const config = require('./cubeConfig')
const Utils = require('./cubeInternalUtils')
const fetchImpl = require('./cubeDependencies').fetchImpl
const formDataImpl = require('./cubeDependencies').formDataImpl

class HTTPProxy {
  constructor() {
    this.sdkInstance = {
      config: config,
      session: null
    }

    this.currentUserId = null

    this.requestsNumber = 0
  }

  setSession(session) {
    this.sdkInstance.session = session

    if (session && session.user_id) {
      this.setCurrentUserId(session.user_id)
    }
  }

  getSession() {
    return this.sdkInstance.session
  }

  setCurrentUserId(userId) {
    this.currentUserId = userId
  }

  getCurrentUserId() {
    return this.currentUserId
  }

  logRequest(params) {
    ++this.requestsNumber

    Utils.DLog(
      '[Request][' + this.requestsNumber + ']',
      (params.type || 'GET') + ' ' + params.url,
      params
    )
  }

  logResponse(response) {
    Utils.DLog('[Response][' + this.requestsNumber + ']', response)
  }

  buildRequestAndURL(params) {
    const isGetOrHeadType = !params.type || params.type === 'GET' || params.type === 'HEAD'
    const isPostOrPutType = params.type && (params.type === 'POST' || params.type === 'PUT')
    const token =
      this.sdkInstance &&
      this.sdkInstance.session &&
      this.sdkInstance.session.token
    const isInternalRequest = params.url.indexOf('s3.amazonaws.com') === -1
    const isMultipartFormData = params.contentType === false

    let requestBody
    let requestURL = params.url
    const requestObject = {}
    let responseObject

    requestObject.method = params.type || 'GET'

    if (params.data) {
      requestBody = this.buildRequestBody(params, isMultipartFormData, isPostOrPutType)

      if (isGetOrHeadType) {
        requestURL += '?' + requestBody
      } else {
        requestObject.body = requestBody
      }
    }

    if (!isMultipartFormData) {
      requestObject.headers = {
        'Content-Type':
          isPostOrPutType ?
            'application/json;charset=utf-8' :
            'application/x-www-form-urlencoded; charset=UTF-8'
      }
    }

    if (isInternalRequest) {
      if (!requestObject.headers) {
        requestObject.headers = {}
      }

      requestObject.headers['CB-SDK'] = 'JS ' + config.version + ' - Client'

      if (token) {
        requestObject.headers['CB-Token'] = token
      }
    }

    if (config.timeout) {
      requestObject.timeout = config.timeout
    }

    return [requestObject, requestURL]
  }

  buildRequestBody(params, isMultipartFormData, isPostOrPutType) {
    const data = params.data

    let dataObject

    if (isMultipartFormData) {
      dataObject = new formDataImpl()

      Object.keys(data).forEach(function (item) {
        if (params.fileToCustomObject && item === 'file') {
          dataObject.append(item, data[item].data, data[item].name)
        } else {
          dataObject.append(item, params.data[item])
        }
      })
    } else if (isPostOrPutType) {
      dataObject = JSON.stringify(data)
    } else {
      dataObject = Object.keys(data)
        .map(k => {
          if (Utils.isObject(data[k])) {
            return Object.keys(data[k])
              .map(v => {
                return (
                  this.encodeURIComponent(k) +
                  '[' +
                  (Utils.isArray(data[k]) ? '' : v) +
                  ']=' +
                  this.encodeURIComponent(data[k][v])
                )
              })
              .sort()
              .join('&')
          } else {
            return (
              this.encodeURIComponent(k) +
              (Utils.isArray(data[k]) ? '[]' : '') +
              '=' +
              this.encodeURIComponent(data[k])
            )
          }
        })
        .sort()
        .join('&')
    }

    return dataObject
  }

  encodeURIComponent(str) {
    return encodeURIComponent(str).replace(/[#$&+,/:;=?@\[\]]/g, function (c) {
      return '%' + c.charCodeAt(0).toString(16)
    })
  }

  ajax(params) {
    return new Promise((resolve, reject) => {
      this.logRequest(params)

      const requestAndURL = this.buildRequestAndURL(params)
      const requestObject = requestAndURL[0]
      const requestURL = requestAndURL[1]

      let response

      // The Promise returned from fetch() won’t reject on HTTP error
      // status even if the response is an HTTP 404 or 500.
      // Instead, it will resolve normally (with ok status set to false),
      // and it will only reject on network failure or if anything prevented the request from completing.
      fetchImpl(requestURL, requestObject)
        .then(resp => {
          response = resp
          const dataType = params.dataType || 'json'
          return dataType === 'text' ? response.text() : response.json()
        })
        .then(body => {
          if (!response.ok) {
            this.processAjaxError(
              response,
              body,
              null,
              reject,
              resolve,
              params
            )
          } else {
            this.processAjaxResponse(body, resolve)
          }
        })
        .catch(error => {
          this.processAjaxError(response, ' ', error, reject, resolve, params)
        })
    })
  }

  processAjaxResponse(body, resolve) {
    const responseBody = body && body !== ' ' ? body : 'empty body'
    this.logResponse(responseBody)

    resolve(body)
  }

  processAjaxError(response, body, error, reject, resolve, params) {
    if (!response && error && !error.code) {
      reject(error)
      return
    }

    const statusCode = response && (response.status || response.statusCode)
    const errorObject = {
      code: (response && statusCode) || (error && error.code),
      info: (body && typeof body === 'string' && body !== ' ' ? JSON.parse(body) : body) || (error && error.errno),
    }

    const responseBody = body || error || body.errors
    this.logResponse(responseBody)

    if (response.url.indexOf(config.urls.session) === -1) {
      if (
        Utils.isExpiredSessionError(errorObject) &&
        typeof config.on.sessionExpired === 'function'
      ) {
        this.handleExpiredSessionResponse(
          errorObject,
          null,
          reject,
          resolve,
          params
        )
      } else {
        reject(errorObject)
      }
    } else {
      reject(errorObject)
    }
  }

  handleExpiredSessionResponse(error, response, reject, resolve, params) {
    const handleResponse = () => {
      if (error) {
        reject(error)
      } else {
        resolve(response)
      }
    }

    const retryCallback = session => {
      if (session) {
        this.setSession(session)
        this.ajax(params)
          .then(resolve)
          .catch(reject)
      }
    }

    config.on.sessionExpired(handleResponse, retryCallback)
  }
}

module.exports = HTTPProxy
