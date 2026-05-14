

/// Các trạng thái animation của nhân vật
enum CharacterState {
  idle,      // Đứng yên, thở nhẹ
  walking,   // Đi bộ - tay chân swing
  jumping,   // Nhảy - tay dang lên, chân gập
  excited,   // Hứng khởi - nhảy + vỗ tay
  thinking,  // Suy nghĩ - tay chống cằm, đuôi vẫy
  waving,    // Vẫy tay chào
}

/// Pose của skeleton tại một thời điểm
class SkeletonPose {
  // Body
  final double bodyOffsetY;      // Độ dịch chuyển Y của thân (bounce)
  final double bodyRotation;     // Xoay thân (lean)

  // Head
  final double headTilt;         // Nghiêng đầu

  // Arms - góc tính bằng radian, 0 = thẳng xuống
  final double leftArmAngle;    // Góc tay trái (từ vai)
  final double rightArmAngle;   // Góc tay phải
  final double leftForearmAngle;  // Góc cẳng tay trái
  final double rightForearmAngle; // Góc cẳng tay phải

  // Legs - góc từ hông
  final double leftThighAngle;
  final double rightThighAngle;
  final double leftShinAngle;
  final double rightShinAngle;

  // Tail - control point offset
  final double tailCurve;       // Độ cong đuôi

  const SkeletonPose({
    this.bodyOffsetY = 0,
    this.bodyRotation = 0,
    this.headTilt = 0,
    this.leftArmAngle = 0.2,
    this.rightArmAngle = -0.2,
    this.leftForearmAngle = 0,
    this.rightForearmAngle = 0,
    this.leftThighAngle = 0,
    this.rightThighAngle = 0,
    this.leftShinAngle = 0,
    this.rightShinAngle = 0,
    this.tailCurve = 0.3,
  });

  /// Lerp giữa 2 pose
  static SkeletonPose lerp(SkeletonPose a, SkeletonPose b, double t) {
    double l(double x, double y) => x + (y - x) * t;
    return SkeletonPose(
      bodyOffsetY: l(a.bodyOffsetY, b.bodyOffsetY),
      bodyRotation: l(a.bodyRotation, b.bodyRotation),
      headTilt: l(a.headTilt, b.headTilt),
      leftArmAngle: l(a.leftArmAngle, b.leftArmAngle),
      rightArmAngle: l(a.rightArmAngle, b.rightArmAngle),
      leftForearmAngle: l(a.leftForearmAngle, b.leftForearmAngle),
      rightForearmAngle: l(a.rightForearmAngle, b.rightForearmAngle),
      leftThighAngle: l(a.leftThighAngle, b.leftThighAngle),
      rightThighAngle: l(a.rightThighAngle, b.rightThighAngle),
      leftShinAngle: l(a.leftShinAngle, b.leftShinAngle),
      rightShinAngle: l(a.rightShinAngle, b.rightShinAngle),
      tailCurve: l(a.tailCurve, b.tailCurve),
    );
  }
}

/// Tập hợp các keyframe pose cho từng state
class CharacterPoses {
  // ─── IDLE ────────────────────────────────────────────────────────────────
  static const SkeletonPose idleA = SkeletonPose(
    bodyOffsetY: 0,
    leftArmAngle: 0.25,
    rightArmAngle: -0.25,
    leftForearmAngle: 0.1,
    rightForearmAngle: -0.1,
    tailCurve: 0.4,
  );
  static const SkeletonPose idleB = SkeletonPose(
    bodyOffsetY: -3,
    leftArmAngle: 0.2,
    rightArmAngle: -0.2,
    leftForearmAngle: 0.05,
    rightForearmAngle: -0.05,
    tailCurve: 0.2,
  );

  // ─── WALKING ─────────────────────────────────────────────────────────────
  static const SkeletonPose walkA = SkeletonPose(
    bodyOffsetY: -2,
    leftArmAngle: -0.6,
    rightArmAngle: 0.6,
    leftForearmAngle: -0.2,
    rightForearmAngle: 0.2,
    leftThighAngle: 0.5,
    rightThighAngle: -0.5,
    leftShinAngle: 0.3,
    rightShinAngle: -0.1,
    tailCurve: 0.5,
  );
  static const SkeletonPose walkB = SkeletonPose(
    bodyOffsetY: 0,
    leftArmAngle: 0.6,
    rightArmAngle: -0.6,
    leftForearmAngle: 0.2,
    rightForearmAngle: -0.2,
    leftThighAngle: -0.5,
    rightThighAngle: 0.5,
    leftShinAngle: -0.1,
    rightShinAngle: 0.3,
    tailCurve: -0.2,
  );

  // ─── JUMPING ─────────────────────────────────────────────────────────────
  static const SkeletonPose jumpA = SkeletonPose(
    bodyOffsetY: -20,
    bodyRotation: 0.05,
    leftArmAngle: -1.2,
    rightArmAngle: 1.2,
    leftForearmAngle: -0.4,
    rightForearmAngle: 0.4,
    leftThighAngle: -0.6,
    rightThighAngle: 0.6,
    leftShinAngle: -0.8,
    rightShinAngle: 0.8,
    tailCurve: -0.6,
  );
  static const SkeletonPose jumpB = SkeletonPose(
    bodyOffsetY: 2,
    bodyRotation: -0.03,
    leftArmAngle: 0.3,
    rightArmAngle: -0.3,
    leftThighAngle: 0.2,
    rightThighAngle: -0.2,
    tailCurve: 0.3,
  );

  // ─── EXCITED ─────────────────────────────────────────────────────────────
  static const SkeletonPose excitedA = SkeletonPose(
    bodyOffsetY: -15,
    headTilt: 0.15,
    leftArmAngle: -1.4,
    rightArmAngle: 1.4,
    leftForearmAngle: 0.5,
    rightForearmAngle: -0.5,
    leftThighAngle: -0.4,
    rightThighAngle: 0.4,
    leftShinAngle: -0.6,
    rightShinAngle: 0.6,
    tailCurve: -0.8,
  );
  static const SkeletonPose excitedB = SkeletonPose(
    bodyOffsetY: 0,
    headTilt: -0.1,
    leftArmAngle: -0.8,
    rightArmAngle: 0.8,
    leftForearmAngle: 0.2,
    rightForearmAngle: -0.2,
    tailCurve: 0.8,
  );

  // ─── THINKING ────────────────────────────────────────────────────────────
  static const SkeletonPose thinkA = SkeletonPose(
    bodyOffsetY: 0,
    headTilt: 0.2,
    leftArmAngle: 0.3,
    rightArmAngle: -1.1,   // Tay phải đưa lên
    rightForearmAngle: -0.5,
    leftThighAngle: 0.1,
    rightThighAngle: -0.1,
    tailCurve: 0.6,
  );
  static const SkeletonPose thinkB = SkeletonPose(
    bodyOffsetY: -2,
    headTilt: 0.25,
    leftArmAngle: 0.3,
    rightArmAngle: -1.15,
    rightForearmAngle: -0.5,
    leftThighAngle: 0.1,
    rightThighAngle: -0.1,
    tailCurve: -0.6,
  );

  // ─── WAVING ──────────────────────────────────────────────────────────────
  static const SkeletonPose waveA = SkeletonPose(
    bodyOffsetY: -2,
    headTilt: 0.1,
    leftArmAngle: 0.25,
    rightArmAngle: -1.5,   // Tay phải đưa cao
    rightForearmAngle: 0.6,
    tailCurve: 0.4,
  );
  static const SkeletonPose waveB = SkeletonPose(
    bodyOffsetY: 0,
    headTilt: -0.05,
    leftArmAngle: 0.25,
    rightArmAngle: -1.3,
    rightForearmAngle: 0.3,
    tailCurve: 0.2,
  );

  /// Lấy cặp keyframe A, B cho state
  static (SkeletonPose, SkeletonPose) forState(CharacterState state) {
    return switch (state) {
      CharacterState.idle => (idleA, idleB),
      CharacterState.walking => (walkA, walkB),
      CharacterState.jumping => (jumpA, jumpB),
      CharacterState.excited => (excitedA, excitedB),
      CharacterState.thinking => (thinkA, thinkB),
      CharacterState.waving => (waveA, waveB),
    };
  }

  /// Duration cho từng state
  static Duration durationFor(CharacterState state) {
    return switch (state) {
      CharacterState.idle => const Duration(milliseconds: 1800),
      CharacterState.walking => const Duration(milliseconds: 500),
      CharacterState.jumping => const Duration(milliseconds: 600),
      CharacterState.excited => const Duration(milliseconds: 350),
      CharacterState.thinking => const Duration(milliseconds: 1400),
      CharacterState.waving => const Duration(milliseconds: 400),
    };
  }
}
