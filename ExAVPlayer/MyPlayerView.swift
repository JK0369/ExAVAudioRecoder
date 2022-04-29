//
//  MyPlayerView.swift
//  ExAVPlayer
//
//  Created by Jake.K on 2022/04/29.
//

import AVFoundation
import RxSwift
import RxCocoa
import UIKit

final class MyPlayerView: UIView {
  private let label: UILabel = {
    let label = UILabel()
    label.text = "AVPlayer"
    label.textColor = .black
    label.translatesAutoresizingMaskIntoConstraints = false
    return label
  }()
  private let button: UIButton = {
    let button = UIButton()
    button.setTitleColor(.systemBlue, for: .normal)
    button.setTitleColor(.blue, for: .highlighted)
    button.setTitle("스트리밍 재생하기", for: .normal)
    button.setTitle("중지", for: .selected)
    button.translatesAutoresizingMaskIntoConstraints = false
    return button
  }()
  
  private let player = AVPlayer()
  var url: URL? {
    didSet {
      self.stop()
      guard self.url != oldValue, let mediaURL = self.url else {
        return self.player.replaceCurrentItem(with: nil)
      }
      self.setPlayerItem(.init(url: mediaURL))
    }
  }
  var item: AVPlayerItem? = nil {
    didSet {
      self.player.replaceCurrentItem(with: self.item)
      self.itemDisposeBag = DisposeBag()
      self.item?.rx.didPlayToEnd
        .map { [weak self] _ in self?.startTime ?? .zero }
        .bind(with: self, onNext: { ss, time in
          ss.player.seek(to: time)
          ss.player.play()
        })
        .disposed(by: self.itemDisposeBag)
    }
  }
  var startTime: CMTime? {
    didSet {
      guard let startTime = self.startTime else { return }
      self.player.seek(to: startTime)
    }
  }
  var elapsedTime: TimeInterval = 0.0
  let remainingSeconds = BehaviorSubject<TimeInterval>(value: 0.0)
  let totalDuration = BehaviorSubject<TimeInterval>(value: 0.0)
  
  private var disposeBag = DisposeBag()
  private var itemDisposeBag = DisposeBag()
  
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
    self.player.play()
  }
  func stop() {
    self.player.pause()
    self.player.seek(to: .zero)
    self.elapsedTime = 0
  }
  
  private func setPlayerItem(_ item: AVPlayerItem) {
    defer { self.player.replaceCurrentItem(with: item) }
    
    item.rx.status
      .filter { $0 == .readyToPlay }
      .observe(on: MainScheduler.asyncInstance)
      .map { _ in item.asset.duration.seconds }
      .bind(with: self) { $0.totalDuration.onNext($1)  }
      .disposed(by: self.itemDisposeBag)
    
    self.player.rx
      .periodicTimeObserver(interval: .init(seconds: 0.1, preferredTimescale: Int32(NSEC_PER_SEC)))
      .map(\.seconds)
      .bind(to: self.rx.elapsedTime)
      .disposed(by: self.disposeBag)
  }
}
