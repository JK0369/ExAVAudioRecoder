//
//  Rx+Extension.swift
//  ExAVPlayer
//
//  Created by Jake.K on 2022/04/29.
//

import RxSwift
import RxCocoa
import AVFoundation

extension Reactive where Base: UIControl {
  public var isHighlighted: Observable<Bool> {
    self.base.rx.methodInvoked(#selector(setter: self.base.isHighlighted))
      .compactMap { $0.first as? Bool }
      .startWith(self.base.isHighlighted)
      .distinctUntilChanged()
      .share()
  }
  public var isSelected: Observable<Bool> {
    self.base.rx.methodInvoked(#selector(setter: self.base.isSelected))
      .compactMap { $0.first as? Bool }
      .startWith(self.base.isSelected)
      .distinctUntilChanged()
      .share()
  }
}

// https://github.com/pmick/RxAVFoundation
extension Reactive where Base: AVPlayerItem {
  public var status: Observable<AVPlayerItem.Status> {
    self.observe(AVPlayerItem.Status.self, #keyPath(AVPlayerItem.status)).map { $0 ?? .unknown }
  }
  public var duration: Observable<CMTime> {
    self.observe(CMTime.self, #keyPath(AVPlayerItem.duration)).map { $0 ?? .zero }
  }
  
  public var didPlayToEnd: Observable<Notification> {
    NotificationCenter.default.rx.notification(.AVPlayerItemDidPlayToEndTime, object: self.base)
  }
}

// https://github.com/pmick/RxAVFoundation
extension Reactive where Base: AVPlayer {
  @available(iOS 10.0, tvOS 10.0, *, OSX 10.12, *)
  public var timeControlStatus: Observable<AVPlayer.TimeControlStatus> {
    self.observe(AVPlayer.TimeControlStatus.self, #keyPath(AVPlayer.timeControlStatus))
      .map { $0 ?? .waitingToPlayAtSpecifiedRate }
  }
  
  public func periodicTimeObserver(interval: CMTime) -> Observable<CMTime> {
    Observable.create { [weak base] observer in
      guard
        let timeObserver = base?.addPeriodicTimeObserver(
          forInterval: interval,
          queue: nil,
          using: observer.onNext
        )
      else { return Disposables.create() }
      return Disposables.create { base?.removeTimeObserver(timeObserver) }
    }
  }
  
  public func boundaryTimeObserver(times: [CMTime]) -> Observable<Void> {
    Observable.create { [weak base] observer in
      let timeValues = times.map(NSValue.init(time:))
      guard
        let timeObserver = base?.addBoundaryTimeObserver(
          forTimes: timeValues,
          queue: nil,
          using: { observer.onNext(()) }
        )
      else { return Disposables.create() }
      return Disposables.create { base?.removeTimeObserver(timeObserver) }
    }
  }
}
