//
//  AlamofireTransport.swift
//
//  Created by Max Desiatov on 1/05/2018.
//  Copyright © 2018 Max Desiatov
//

import Alamofire
import Apollo
import Foundation

/// A network transport that uses HTTP POST requests to send GraphQL operations
/// to a server, and that uses `Alamofire.SessionManager` as the networking
/// implementation.
public class AlamofireTransport: NetworkTransport {
  let sessionManager: SessionManager
  let url: URL
  public var headers: HTTPHeaders?
  public var loggingEnabled: Bool

  public init(url: URL, sessionManager: SessionManager = SessionManager.default,
              headers: HTTPHeaders? = nil, loggingEnabled: Bool = false) {
    self.sessionManager = sessionManager
    self.url = url
    self.headers = headers
    self.loggingEnabled = loggingEnabled
  }

  public func send<Operation>(operation: Operation,
                              completionHandler: @escaping (_ result: Swift.Result<Apollo.GraphQLResponse<Operation>, Error>) -> Void)
      -> Cancellable where Operation : GraphQLOperation  {
    let vars: JSONEncodable = operation.variables?.mapValues { $0?.jsonValue }
    let body: Parameters = [
      "query": operation.queryDocument,
      "variables": vars,
    ]
    let request = sessionManager
      .request(url, method: .post, parameters: body,
               encoding: JSONEncoding.default, headers: headers)
      .validate(statusCode: [200])
    if loggingEnabled {
      debugPrint(request)
    }
    return request.responseJSON { response in
      switch response.result {
        case .failure(let error):
            completionHandler(.failure(error))
        case .success(let data):
            if self.loggingEnabled, let data = response.data,
              let str = String(data: data, encoding: .utf8) {
              print(str)
            }

            guard let value = data as? JSONObject else {
              print("Response data not a JSONObject! ")
              return
            }
            
            let gqlResult = GraphQLResponse(operation: operation, body: value)
            completionHandler(.success(gqlResult))
        }
    }.task!
  }
}
