import Foundation
import AVFoundation
import Pitchy

public protocol PitchEngineDelegate: class {
  func pitchEngineDidRecievePitch(pitchEngine: PitchEngine, pitch: Pitch)
  func pitchEngineDidRecieveError(pitchEngine: PitchEngine, error: ErrorType)
}

public class PitchEngine {

  public enum Error: ErrorType {
    case RecordPermissionDenied
  }

  public enum Mode {
    case Record, Playback
  }

  public let bufferSize: AVAudioFrameCount
  public var active = false
  public weak var delegate: PitchEngineDelegate?

  private var transformer: TransformAware
  private var estimator: EstimationAware
  private var signalTracker: SignalTrackingAware

  public var mode: Mode {
    return signalTracker is InputSignalTracker ? .Record : .Playback
  }

  // MARK: - Initialization

  public init(config: Config, delegate: PitchEngineDelegate? = nil) {
    bufferSize = config.bufferSize
    transformer = TransformFactory.create(config.transformStrategy)
    estimator = EstimationFactory.create(config.estimationStrategy)

    if let audioURL = config.audioURL {
      signalTracker = OutputSignalTracker(audioURL: audioURL, bufferSize: bufferSize)
    } else {
      signalTracker = InputSignalTracker(bufferSize: bufferSize)
    }
    
    signalTracker.delegate = self

    self.delegate = delegate
  }

  // MARK: - Processing

  public func start() {
    guard mode == .Playback else {
      activate()
      return
    }

    AVAudioSession.sharedInstance().requestRecordPermission { [weak self] granted  in
      guard let weakSelf = self else { return }

      guard granted else {
        weakSelf.delegate?.pitchEngineDidRecieveError(weakSelf,
          error: Error.RecordPermissionDenied)
        return
      }

      dispatch_async(dispatch_get_main_queue()) {
        weakSelf.activate()
      }
    }
  }

  public func stop() {
    signalTracker.stop()
    active = false
  }

  private func activate() {
    do {
      try signalTracker.start()
      active = true
    } catch {
      delegate?.pitchEngineDidRecieveError(self, error: error)
    }
  }
}

// MARK: - SignalTrackingDelegate

extension PitchEngine: SignalTrackingDelegate {

  public func signalTracker(signalTracker: SignalTrackingAware,
    didReceiveBuffer buffer: AVAudioPCMBuffer, atTime time: AVAudioTime) {
      dispatch_async(dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0)) { [weak self] in
        guard let weakSelf = self else { return }

        let transformedBuffer = weakSelf.transformer.transformBuffer(buffer)

        do {
          let frequency = try weakSelf.estimator.estimateFrequency(Float(time.sampleRate),
            buffer: transformedBuffer)
          let pitch = Pitch(frequency: Double(frequency))

          weakSelf.delegate?.pitchEngineDidRecievePitch(weakSelf, pitch: pitch)
        } catch {
          weakSelf.delegate?.pitchEngineDidRecieveError(weakSelf, error: error)
        }
    }
  }
}