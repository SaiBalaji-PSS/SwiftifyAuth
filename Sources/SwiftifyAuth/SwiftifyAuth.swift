// The Swift Programming Language
// https://docs.swift.org/swift-book

import Foundation
import AuthenticationServices


protocol SwiftyAuthDelegate: AnyObject{
    func didAuthenticateSuccess(authenticationToken: String)
    func didAuthenticateFail(error: Error?)
}



@available(iOS 13.0, *)
public class SwiftifyAuth{
    var clientId: String
    var scopes: String
    var clientSecret: String
    var presentationContext: ASWebAuthenticationPresentationContextProviding?
    var presentationAnchor: ASPresentationAnchor?
    weak var authDelegate: SwiftyAuthDelegate?
    
    init(clientId: String,scopes: String,clientSecret: String) {
        self.clientId = clientId
        self.scopes = scopes
        self.clientSecret = clientSecret
    }
    
    
    func showAuthScreen(urlScheme: String?,redirectURL: String?){
        if let urlString = createSpotifyURL(redirectURL: redirectURL){
            if let url = URL(string: urlString){
                let session = ASWebAuthenticationSession(url: url, callbackURLScheme: urlScheme ?? nil) { [self] url , error  in
                    if let error{
                       
                        authDelegate?.didAuthenticateFail(error: error)
                    }
                    if let url{
                      
                        if let code = url.getQueryParameter("code"), let redirectURL{
                            self.getAccessToken(code: code, redirectURL: redirectURL)
                        }
                            
                    }
                }
                session.presentationContextProvider = presentationContext
                session.start()
            }
           
        }
    }
    
    private func getAccessToken(code: String,redirectURL: String){
        let url = URL(string: "https://accounts.spotify.com/api/token")
        var request = URLRequest(url: url!)
        request.httpMethod = "POST"
        let postData = "code=\(code)&redirect_uri=\("\(redirectURL)")&grant_type=authorization_code"
        request.httpBody = postData.data(using: .utf8)
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        // Set the authorization header
        let clientCredentials = "\(self.clientId):\(self.clientSecret)"
        if let data = clientCredentials.data(using: .utf8) {
            let base64Credentials = data.base64EncodedString()
            request.setValue("Basic \(base64Credentials)", forHTTPHeaderField: "Authorization")
        }
        let session = URLSession(configuration: .default)
        let task = session.dataTask(with: request) { data , response , error  in
            DispatchQueue.main.async {
                if let error{
                 
                    self.authDelegate?.didAuthenticateFail(error: error)
                }
                if let data{
                    do {
                           if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                               print(json["access_token"])
                               if let bearerToken = json["access_token"] as? String{
                                 //  UserDefaults.standard.set(bearerToken, forKey: "TOKEN")
                                   self.authDelegate?.didAuthenticateSuccess(authenticationToken: bearerToken)
                                  
                               }
                           }
                       } catch {
                           print("Error deserializing JSON: \(error)")
                       }
                }
            }
         
        }
        task.resume()
    }
    
    
    private func createSpotifyURL(redirectURL: String?) -> String?{
        var components = URLComponents()
        components.scheme = "https"
        components.host = "accounts.spotify.com"
        components.path = "/authorize"
        components.queryItems = [
            URLQueryItem(name: "client_id", value: "\(self.clientId)"),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "redirect_uri", value: "\(redirectURL ?? "")"),
            URLQueryItem(name: "scope", value: "\(self.scopes)"),
            URLQueryItem(name: "show_dialog", value: "true")
            
        ]
        return components.string
    }
}


@available(iOS 13.0, *)
extension SwiftifyAuth{
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        return presentationAnchor ?? ASPresentationAnchor()
    }
}

extension URL {
    func getQueryParameter(_ parameter: String) -> String? {
        guard let url = URLComponents(string: self.absoluteString) else { return nil }
        return url.queryItems?.first(where: { $0.name == parameter })?.value
    }
}
