import 'package:liveness_detection_flutter_plugin/index.dart';

abstract class LivenessThreshold extends Equatable {
  const LivenessThreshold();
  LivenessThreshold fromDict(Map<String, dynamic> map);
  Map<String, dynamic> toMap();
  @override
  List<Object> get props => [];
}

// Smile Threshold Default Value: `0.75`
class LivenessThresholdSmile extends LivenessThreshold {
  final double probability;

  LivenessThresholdSmile({
    this.probability = 0.75,
  }) : super() {
    assert(
      probability < 1.0 || probability > 0.0,
      "Smile Probability has to be between 1.0 and 0.0",
    );
  }

  LivenessThresholdSmile copyWith({
    double? probability,
  }) {
    return LivenessThresholdSmile(
      probability: probability ?? this.probability,
    );
  }

  @override
  Map<String, dynamic> toMap() {
    final result = <String, dynamic>{};

    result.addAll({'probability': probability});

    return result;
  }

  @override
  factory LivenessThresholdSmile.fromMap(Map<String, dynamic> map) {
    return LivenessThresholdSmile(
      probability: map['probability']?.toDouble() ?? 0.0,
    );
  }

  String toJson() => json.encode(toMap());

  factory LivenessThresholdSmile.fromJson(String source) =>
      LivenessThresholdSmile.fromMap(json.decode(source));

  @override
  String toString() => 'LivenessThresholdSmile(probability: $probability)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is LivenessThresholdSmile && other.probability == probability;
  }

  @override
  int get hashCode => probability.hashCode;

  @override
  LivenessThresholdSmile fromDict(Map<String, dynamic> map) {
    return LivenessThresholdSmile(
      probability: map['probability']?.toDouble() ?? 0.0,
    );
  }
}

  // Blink detection
  /// To get precise results pass the value close to `0`, e.g. `0.2`
  /// To relax the precision pass the value towards `1`, e.g. `0.5`
  /// Default Value: `0.25` 
class LivenessThresholdBlink extends LivenessThreshold {

  final double leftEyeProbability;
  final double rightEyeProbability;

  LivenessThresholdBlink({
    this.leftEyeProbability = 0.25,
    this.rightEyeProbability = 0.25,
  }) : super() {
    assert(
      leftEyeProbability < 1.0 || leftEyeProbability > 0.0,
      "Left Probability has to be between 1.0 and 0.0",
    );
    assert(
      rightEyeProbability < 1.0 || rightEyeProbability > 0.0,
      "Right Probability has to be between 1.0 and 0.0",
    );
  }

  LivenessThresholdBlink copyWith({
    double? leftEyeProbability,
    double? rightEyeProbability,
  }) {
    return LivenessThresholdBlink(
      leftEyeProbability: leftEyeProbability ?? this.leftEyeProbability,
      rightEyeProbability: rightEyeProbability ?? this.rightEyeProbability,
    );
  }

  @override
  Map<String, dynamic> toMap() {
    final result = <String, dynamic>{};

    result.addAll({'leftEyeProbability': leftEyeProbability});
    result.addAll({'rightEyeProbability': rightEyeProbability});

    return result;
  }

  factory LivenessThresholdBlink.fromMap(Map<String, dynamic> map) {
    return LivenessThresholdBlink(
      leftEyeProbability: map['leftEyeProbability']?.toDouble() ?? 0.0,
      rightEyeProbability: map['rightEyeProbability']?.toDouble() ?? 0.0,
    );
  }

  String toJson() => json.encode(toMap());

  factory LivenessThresholdBlink.fromJson(String source) =>
      LivenessThresholdBlink.fromMap(json.decode(source));

  @override
  String toString() =>
      'LivenessThresholdBlink(leftEyeProbability: $leftEyeProbability, rightEyeProbability: $rightEyeProbability)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is LivenessThresholdBlink &&
        other.leftEyeProbability == leftEyeProbability &&
        other.rightEyeProbability == rightEyeProbability;
  }

  @override
  int get hashCode =>
      leftEyeProbability.hashCode ^ rightEyeProbability.hashCode;

  @override
  LivenessThreshold fromDict(Map<String, dynamic> map) {
    return LivenessThresholdBlink(
      leftEyeProbability: map['leftEyeProbability']?.toDouble() ?? 0.0,
      rightEyeProbability: map['rightEyeProbability']?.toDouble() ?? 0.0,
    );
  }
}

class LivenessThresholdHead extends LivenessThreshold{
  /// Threshold of head angle at which the head turn will be considered as verified
  /// A `Positive` Value will be considered as detection on the `Left` size and
  /// A `Negative` Value will be considered as detection on the `Right` size.
  /// Default Value: `45`, i.e., the head turn will be checked on the `Left Side`
  final double rotationAngle;

  LivenessThresholdHead({
    this.rotationAngle = 45.0,
  }) : super() {
    assert(
      rotationAngle > 180.0 || rotationAngle > 0.0,
      "To detect the livelyness of the face, it has to be properly visible in the camera. The threshold angle should be more than 0.0 degrees and less than 180 degrees.",
    );
  }

  LivenessThresholdHead copyWith({
    double? rotationAngle,
  }) {
    return LivenessThresholdHead(
      rotationAngle: rotationAngle ?? this.rotationAngle,
    );
  }

  @override
  Map<String, dynamic> toMap() {
    final result = <String, dynamic>{};

    result.addAll({'rotationAngle': rotationAngle});

    return result;
  }

  factory LivenessThresholdHead.fromMap(Map<String, dynamic> map) {
    return LivenessThresholdHead(
      rotationAngle: map['rotationAngle']?.toDouble() ?? 0.0,
    );
  }

  String toJson() => json.encode(toMap());

  factory LivenessThresholdHead.fromJson(String source) =>
      LivenessThresholdHead.fromMap(json.decode(source));

  @override
  String toString() =>
      'LivenessThresholdHead(rotationAngle: $rotationAngle)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is LivenessThresholdHead &&
        other.rotationAngle == rotationAngle;
  }

  @override
  int get hashCode => rotationAngle.hashCode;

  @override
  LivenessThreshold fromDict(Map<String, dynamic> map) {
    return LivenessThresholdHead(
      rotationAngle: map['rotationAngle']?.toDouble() ?? 0.0,
    );
  }
}