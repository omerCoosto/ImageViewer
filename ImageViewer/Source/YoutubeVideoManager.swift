//
//  YoutubeVideoManager.swift
//  ImageViewer
//
//  Created by omer ozkul on 19/06/2019.
//  Copyright © 2019 MailOnline. All rights reserved.
//

import Foundation

class YoutubeVideoManager {
    static func playerHtmlContent(videoId: String) -> String {
        return "<html>" +
            "<body style=\"margin:0px;padding:0px;\">" +
            "<script type=\"text/javascript\" src=\"http://www.youtube.com/iframe_api\"></script>" +
            "<script type=\"text/javascript\">" +
            "function onYouTubeIframeAPIReady() {" +
            "ytplayer=new YT.Player('playerId',{events:{onReady:onPlayerReady}});" +
            "}" +
            "function onPlayerReady(a) { a.target.playVideo(); }" +
            "</script>" +
            "<iframe webkit-playsinline id=\"playerId\" type=\"text/html\" width=100% height=100% src=\"https://www.youtube.com/embed/\(videoId)?playsinline=1&rel=0&showinfo=0&fs=1\" frameborder='0'/>" +
        "</body> </html>"
    }

    static func isYoutubeUrl(_ urlStr: String) -> Bool {
        let pattern = "^(https?\\:\\/\\/)?(www\\.)?(youtube\\.com|youtu\\.?be)\\/.+$"
        let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive)
        let range = NSRange(location: 0, length: urlStr.count)
        
        return regex?.firstMatch(in: urlStr, range: range) != nil
    }
    
    static func youtubeId(from urlStr: String) -> String? {
        let pattern = "((?<=(v|V)/)|(?<=be/)|(?<=(\\?|\\&)v=)|(?<=embed/))([\\w-]++)"
        let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive)
        let range = NSRange(location: 0, length: urlStr.count)
        
        guard let result = regex?.firstMatch(in: urlStr, range: range) else { return nil }
        return (urlStr as NSString).substring(with: result.range)
    }
}
