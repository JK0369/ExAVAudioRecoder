//
//  MyAudioPlayerView.swift
//  ExAVPlayer
//
//  Created by Jake.K on 2022/04/29.
//

import UIKit
import AVFoundation
import RxSwift
import RxCocoa

final class MyAudioPlayerView: UIView {
  private let label: UILabel = {
    let label = UILabel()
    label.text = "AVAudioPlayer"
    label.textColor = .black
    label.translatesAutoresizingMaskIntoConstraints = false
    label.isHidden = true
    return label
  }()
  private let button: UIButton = {
    let button = UIButton()
    button.setTitleColor(.systemBlue, for: .normal)
    button.setTitleColor(.blue, for: .highlighted)
    button.setTitle("녹음본 재생하기", for: .normal)
    button.setTitle("중지", for: .selected)
    button.isHidden = true
    button.translatesAutoresizingMaskIntoConstraints = false
    return button
  }()
  
  var url: URL?
  var isLocal = true
  var elapsedTime: TimeInterval = 0.0 {
    didSet {
      try? self.remainingSeconds.onNext(self.totalDuration.value() - self.elapsedTime)
    }
  }
  var readyToPlay: Bool? {
    didSet {
      self.button.isHidden = !(self.readyToPlay == true)
      self.label.isHidden = !(self.readyToPlay == true)
    }
  }
  let remainingSeconds = BehaviorSubject<TimeInterval>(value: 0.0)
  let totalDuration = BehaviorSubject<TimeInterval>(value: 0.0)
  
  private var audioPlayer: AVAudioPlayer? {
    didSet {
      self.audioPlayer?.delegate = self
      self.audioPlayer?.prepareToPlay()
    }
  }
  private var disposeBag = DisposeBag()
  private var playerDisposeBag = DisposeBag()
  private var playDisposeBag = DisposeBag()

  required init?(coder: NSCoder) {
    fatalError()
  }
  override init(frame: CGRect) {
    super.init(frame: frame)
    self.addSubview(self.label)
    self.addSubview(self.button)
    
    NSLayoutConstraint.activate([
      self.label.leftAnchor.constraint(equalTo: self.leftAnchor),
      self.label.bottomAnchor.constraint(equalTo: self.bottomAnchor),
      self.label.topAnchor.constraint(equalTo: self.topAnchor),
    ])
    NSLayoutConstraint.activate([
      self.button.leftAnchor.constraint(equalTo: self.label.rightAnchor, constant: 16),
      self.button.rightAnchor.constraint(equalTo: self.rightAnchor),
      self.button.centerYAnchor.constraint(equalTo: self.label.centerYAnchor)
    ])
    
    self.button.rx.isHighlighted
      .filter { $0 == true }
      .withLatestFrom(self.button.rx.isSelected)
      .map { !$0 }
      .do { [weak self] in $0 ? self?.play() : self?.stop() }
      .bind(to: self.button.rx.isSelected)
      .disposed(by: self.disposeBag)
  }
  
  func play() {
    guard let url = url else { return }

    if self.isLocal {
      self.audioPlayer = try? AVAudioPlayer(contentsOf: url)
    } else {
      URLSession.shared.rx.data(request: .init(url: url))
        .compactMap { try? AVAudioPlayer(data: $0) }
        .observe(on: MainScheduler.asyncInstance)
        .subscribe(onNext: { [weak self]
          in self?.audioPlayer = $0
          self?.button.isHidden = false
        })
        .disposed(by: self.playerDisposeBag)
    }
    
    Observable<Int>
      .interval(.seconds(1), scheduler: MainScheduler.asyncInstance)
      .compactMap { [weak self] _ in self?.audioPlayer?.currentTime }
      .bind(to: self.rx.elapsedTime)
      .disposed(by: self.playDisposeBag)
    
    self.audioPlayer?.play()
  }
  private func stop() {
    self.audioPlayer?.pause()
    self.elapsedTime = 0
    self.playerDisposeBag = DisposeBag()
  }
}

extension MyAudioPlayerView: AVAudioPlayerDelegate {
  func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
    guard let error = error else { return }
    print("occured error = \(error)")
  }
  func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
    print("did finish playing")
  }
}
