//
//  ImageViewController.swift
//  ImageViewer
//
//  Created by Kristian Angyal on 01/08/2016.
//  Copyright © 2016 MailOnline. All rights reserved.
//

import UIKit
import AVFoundation
import WebKit

extension VideoView: ItemView {}

class VideoViewController: ItemBaseController<VideoView>, WKNavigationDelegate {

    fileprivate let swipeToDismissFadeOutAccelerationFactor: CGFloat = 6

    let videoURL: URL
    let player: AVPlayer
    unowned let scrubber: VideoScrubber

    let fullHDScreenSizeLandscape = CGSize(width: 1920, height: 1080)
    let fullHDScreenSizePortrait = CGSize(width: 1080, height: 1920)
    let embeddedPlayButton = UIButton.circlePlayButton(70)
    
    private var autoPlayStarted: Bool = false
    private var autoPlayEnabled: Bool = false

    init(index: Int, itemCount: Int, fetchImageBlock: @escaping FetchImageBlock, videoURL: URL, scrubber: VideoScrubber, configuration: GalleryConfiguration, isInitialController: Bool = false) {

        self.videoURL = videoURL
        self.scrubber = scrubber
        self.player = AVPlayer(url: self.videoURL)
        
        ///Only those options relevant to the paging VideoViewController are explicitly handled here, the rest is handled by ItemViewControllers
        for item in configuration {
            
            switch item {
                
            case .videoAutoPlay(let enabled):
                autoPlayEnabled = enabled
                
            default: break
            }
        }

        super.init(index: index, itemCount: itemCount, fetchImageBlock: fetchImageBlock, configuration: configuration, isInitialController: isInitialController)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        if isInitialController == true { embeddedPlayButton.alpha = 0 }

        if self.videoURL.host == "www.youtube.com" {
            self.itemView.ytPlayer = self.createYTPlayer()
            self.scrubber.isHidden = true
        } else {
            embeddedPlayButton.autoresizingMask = [.flexibleTopMargin, .flexibleLeftMargin, .flexibleBottomMargin, .flexibleRightMargin]
            self.view.addSubview(embeddedPlayButton)
            embeddedPlayButton.center = self.view.boundsCenter
            
            embeddedPlayButton.addTarget(self, action: #selector(playVideoInitially), for: UIControlEvents.touchUpInside)

            self.itemView.player = player
        }
        self.itemView.contentMode = .scaleAspectFill
    }

    func createEmbedFBPlayer() -> WKWebView {
        let webView = createWKWebView()
        loadContentOfFile(name: "FBPlayer", withUrlStr: self.videoURL.absoluteString, inWebView: webView)
        return webView
    }
    
    func createYTPlayer() -> WKWebView {
        let webView = createWKWebView()
        var urlStr = self.videoURL.absoluteString
        if let query = self.videoURL.query {
            urlStr = self.videoURL.absoluteString.replacingOccurrences(of: "?" + query, with: "")
        }
        loadContentOfFile(name: "YTPlayer", withUrlStr: urlStr, inWebView: webView)
        return webView
    }
    
    func createWKWebView() -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        if #available(iOS 10.0, *) {
            config.mediaTypesRequiringUserActionForPlayback = .video
        }
        let webView = WKWebView(frame: CGRect(x: 0, y: 0, width: itemView.bounds.width, height: itemView.bounds.height),
                                configuration: config)
        webView.backgroundColor = UIColor.black
        webView.isOpaque = false
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.pinchGestureRecognizer?.isEnabled = false
        webView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        webView.navigationDelegate = self
        return webView
    }
    
    func loadContentOfFile(name: String, withUrlStr urlStr: String, inWebView webView: WKWebView) {
        if let htmlFile = Bundle.main.path(forResource: name, ofType: "html"),
            let html = try? String(contentsOfFile: htmlFile, encoding: String.Encoding.utf8) {
            webView.loadHTMLString(html.replacingOccurrences(of: "%@", with: urlStr), baseURL: nil)
        }
    }

    override func viewWillAppear(_ animated: Bool) {

        self.player.addObserver(self, forKeyPath: "status", options: NSKeyValueObservingOptions.new, context: nil)
        self.player.addObserver(self, forKeyPath: "rate", options: NSKeyValueObservingOptions.new, context: nil)

        UIApplication.shared.beginReceivingRemoteControlEvents()

        super.viewWillAppear(animated)
    }

    override func viewWillDisappear(_ animated: Bool) {

        self.player.removeObserver(self, forKeyPath: "status")
        self.player.removeObserver(self, forKeyPath: "rate")

        UIApplication.shared.endReceivingRemoteControlEvents()

        super.viewWillDisappear(animated)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        performAutoPlay()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)

        self.player.pause()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        let isLandscape = itemView.bounds.width >= itemView.bounds.height
        itemView.bounds.size = aspectFitSize(forContentOfSize: isLandscape ? fullHDScreenSizeLandscape : fullHDScreenSizePortrait, inBounds: self.scrollView.bounds.size)
        itemView.center = scrollView.boundsCenter
        itemView.ytPlayer?.frame = CGRect(x: 0, y: 0, width: itemView.bounds.size.width, height: itemView.bounds.size.height)
    }

    @objc func playVideoInitially() {

        self.player.play()


        UIView.animate(withDuration: 0.25, animations: { [weak self] in

            self?.embeddedPlayButton.alpha = 0

        }, completion: { [weak self] _ in

            self?.embeddedPlayButton.isHidden = true
        })
    }

    override func closeDecorationViews(_ duration: TimeInterval) {

        UIView.animate(withDuration: duration, animations: { [weak self] in

            self?.embeddedPlayButton.alpha = 0
            self?.itemView.previewImageView.alpha = 1
        })
    }

    override func presentItem(alongsideAnimation: () -> Void, completion: @escaping () -> Void) {

        let circleButtonAnimation = {

            UIView.animate(withDuration: 0.15, animations: { [weak self] in
                self?.embeddedPlayButton.alpha = 1
            })
        }

        super.presentItem(alongsideAnimation: alongsideAnimation) {

            circleButtonAnimation()
            completion()
        }
    }

    override func displacementTargetSize(forSize size: CGSize) -> CGSize {

        let isLandscape = itemView.bounds.width >= itemView.bounds.height
        return aspectFitSize(forContentOfSize: isLandscape ? fullHDScreenSizeLandscape : fullHDScreenSizePortrait, inBounds: rotationAdjustedBounds().size)
    }

    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {

        if keyPath == "rate" || keyPath == "status" {

            fadeOutEmbeddedPlayButton()
        }

        else if keyPath == "contentOffset" {

            handleSwipeToDismissTransition()
        }

        super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
    }

    func handleSwipeToDismissTransition() {

        guard let _ = swipingToDismiss else { return }

        embeddedPlayButton.center.y = view.center.y - scrollView.contentOffset.y
    }

    func fadeOutEmbeddedPlayButton() {

        if player.isPlaying() && embeddedPlayButton.alpha != 0  {

            UIView.animate(withDuration: 0.3, animations: { [weak self] in

                self?.embeddedPlayButton.alpha = 0
            })
        }
    }

    override func remoteControlReceived(with event: UIEvent?) {

        if let event = event {

            if event.type == UIEventType.remoteControl {

                switch event.subtype {

                case .remoteControlTogglePlayPause:

                    if self.player.isPlaying()  {

                        self.player.pause()
                    }
                    else {

                        self.player.play()
                    }

                case .remoteControlPause:

                    self.player.pause()

                case .remoteControlPlay:

                    self.player.play()

                case .remoteControlPreviousTrack:

                    self.player.pause()
                    self.player.seek(to: CMTime(value: 0, timescale: 1))
                    self.player.play()

                default:

                    break
                }
            }
        }
    }
    
    private func performAutoPlay() {
        guard autoPlayEnabled else { return }
        guard autoPlayStarted == false else { return }
        
        autoPlayStarted = true
        embeddedPlayButton.isHidden = true
        scrubber.play()
    }
    
    // MARK: - WKNavigationDelegate
    
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        self.activityIndicatorView.startAnimating()
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        self.activityIndicatorView.stopAnimating()
        UIView.animate(withDuration: 0.3, animations: { [weak self] in
            self?.itemView.previewImageView.alpha = 0
        })
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        self.activityIndicatorView.stopAnimating()
        self.itemView.previewImageView.alpha = 1
    }
    
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        self.activityIndicatorView.stopAnimating()
        self.itemView.previewImageView.alpha = 1
    }
}
