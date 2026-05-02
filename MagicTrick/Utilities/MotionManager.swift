import CoreMotion
import Combine

/// Detects shake gestures using the accelerometer.
/// `isShaking` becomes true after 3 rapid shakes, false after 0.4s of stillness.
final class MotionManager: ObservableObject {
    static let shared = MotionManager()

    private let motion = CMMotionManager()
    private var timer: Timer?

    @Published var isShaking = false

    private let shakeThreshold: Double = 1.8   // G-force threshold
    private var shakeCount = 0
    private var lastShakeTime: Date = .distantPast

    private init() {}

    func startMonitoring() {
        guard motion.isAccelerometerAvailable else { return }
        motion.accelerometerUpdateInterval = 0.05 // 20Hz
        motion.startAccelerometerUpdates()

        timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            guard let self = self,
                  let data = self.motion.accelerometerData else { return }

            let totalG = sqrt(
                pow(data.acceleration.x, 2) +
                pow(data.acceleration.y, 2) +
                pow(data.acceleration.z, 2)
            )

            if totalG > self.shakeThreshold {
                let now = Date()
                if now.timeIntervalSince(self.lastShakeTime) < 0.3 {
                    self.shakeCount += 1
                } else {
                    self.shakeCount = 1
                }
                self.lastShakeTime = now

                if self.shakeCount >= 3 && !self.isShaking {
                    DispatchQueue.main.async {
                        self.isShaking = true
                    }
                }
            } else {
                // No shake — check if shaking has stopped
                if self.isShaking && Date().timeIntervalSince(self.lastShakeTime) > 0.4 {
                    DispatchQueue.main.async {
                        self.isShaking = false
                    }
                }
            }
        }
    }

    func stopMonitoring() {
        motion.stopAccelerometerUpdates()
        timer?.invalidate()
        timer = nil
    }
}
