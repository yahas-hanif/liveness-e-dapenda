import 'dart:async';
import 'dart:ui' as ui;
import 'package:camera/camera.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:liveness_detection_flutter_plugin/index.dart';

List<CameraDescription> availableCams = [];

class LivenessDetectionScreen extends StatefulWidget {
  final LivenessConfig config;
  const LivenessDetectionScreen({super.key, required this.config});

  @override
  State<LivenessDetectionScreen> createState() =>
      _LivenessDetectionScreenState();
}

class _LivenessDetectionScreenState extends State<LivenessDetectionScreen>
    with TickerProviderStateMixin {
  AnimationController? controller;
  Animation<double>? animation;
  late bool _isInfoStepCompleted;
  late final List<LivenessDetectionStepItem> steps;
  CameraController? _cameraController;
  CustomPaint? _customPaint;
  int _cameraIndex = 0;
  bool _isBusy = false;
  final GlobalKey<LivenessDetectionStepOverlayState> _stepsKey =
      GlobalKey<LivenessDetectionStepOverlayState>();
  bool _isProcessingStep = false;
  bool _didCloseEyes = false;
  bool _isTakingPicture = false;
  Timer? _timerToDetectFace;
  CameraImage? _cameraImage;

  bool _prosesCameraImage = true;

  late final List<LivenessDetectionStepItem> _steps;

  @override
  void initState() {
    _preInitCallBack();
    controller = AnimationController(
      vsync: this,
      duration: Duration(seconds: 2),
    );

    animation = Tween<double>(
      begin: 0.0,
      end: 2 * 3.141592653589793, // 2π radians (full circle)
    ).animate(controller!);

    controller!.repeat();
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _postFrameCallBack(),
    );
  }

  @override
  void dispose() {
    _timerToDetectFace?.cancel();
    _timerToDetectFace = null;
    _cameraController?.dispose();
    _cameraController?.stopImageStream();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // ignore: deprecated_member_use
    return WillPopScope(
      onWillPop: () async {
        _cameraController!.dispose();
        _cameraController!.stopImageStream();
        Navigator.pop(context);
        return true;
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          minimum: const EdgeInsets.all(10),
          child: _buildBody(),
        ),
      ),
    );
  }

  void _preInitCallBack() {
    _steps = widget.config.steps;
    _isInfoStepCompleted = !widget.config.startWithInfoScreen;
  }

  void _postFrameCallBack() async {
    availableCams = await availableCameras();
    if (availableCams.any(
      (element) =>
          element.lensDirection == CameraLensDirection.front &&
          element.sensorOrientation == 90,
    )) {
      _cameraIndex = availableCams.indexOf(
        availableCams.firstWhere((element) =>
            element.lensDirection == CameraLensDirection.front &&
            element.sensorOrientation == 90),
      );
    } else {
      _cameraIndex = availableCams.indexOf(
        availableCams.firstWhere(
          (element) => element.lensDirection == CameraLensDirection.front,
        ),
      );
    }
    if (!widget.config.startWithInfoScreen) {
      _startLiveFeed();
    }
  }

  void _startLiveFeed() async {
    final camera = availableCams[_cameraIndex];
    _cameraController = CameraController(
      camera,
      imageFormatGroup: ImageFormatGroup.yuv420,
      ResolutionPreset.low,
      enableAudio: false,
    );
    _cameraController?.initialize().then((_) {
      if (!mounted) {
        return;
      }
      _cameraController?.startImageStream(_processCameraImage);
      setState(() {});
    });
    _startFaceDetectionTimer();
  }

  void _startFaceDetectionTimer() {
    // Create a Timer that runs for 45 seconds and calls _onDetectionCompleted after that.
    _timerToDetectFace = Timer(const Duration(seconds: 45), () {
      _onDetectionCompleted(imgToReturn: null); // Pass null or "" as needed.
    });
  }

  Future<void> _processCameraImage(CameraImage cameraImage) async {
    final WriteBuffer allBytes = WriteBuffer();
    for (final Plane plane in cameraImage.planes) {
      allBytes.putUint8List(plane.bytes);
    }
    final bytes = allBytes.done().buffer.asUint8List();

    final Size imageSize = Size(
      cameraImage.width.toDouble(),
      cameraImage.height.toDouble(),
    );
    print("SIZED ");
    print(imageSize);

    final camera = availableCams[_cameraIndex];
    final imageRotation = InputImageRotationValue.fromRawValue(
      camera.sensorOrientation,
    );
    if (imageRotation == null) return;

    final inputImageFormat = InputImageFormatValue.fromRawValue(
      cameraImage.format.raw,
    );
    if (inputImageFormat == null) return;

    final planeData = cameraImage.planes.map(
      (Plane plane) {
        return InputImageMetadata(
          bytesPerRow: plane.bytesPerRow,
          size: Size(plane.width == null ? 0 : plane.width!.toDouble(),
              plane.height == null ? 0 : plane.height!.toDouble()),
          rotation: imageRotation,
          format: inputImageFormat,
        );
      },
    ).toList();

    final inputImageData = InputImageMetadata(
      size: imageSize,
      rotation: imageRotation,
      format: inputImageFormat,
      bytesPerRow: planeData.first.bytesPerRow,
    );

    final inputImage = InputImage.fromBytes(
      bytes: bytes,
      metadata: inputImageData,
    );

    if (_prosesCameraImage) {
      _cameraImage = cameraImage;
      print("TAKE FOTO");

      _prosesCameraImage = false;
    }

    _processImage(inputImage);
  }

  Future<void> _processImage(InputImage inputImage) async {
    if (_isBusy) {
      return;
    }
    _isBusy = true;
    final faces =
        await MachineLearningHelper.instance.processInputImage(inputImage);

    if (inputImage.metadata?.size != null &&
        inputImage.metadata?.rotation != null) {
      if (faces.isEmpty) {
        _resetSteps();
      } else {
        final firstFace = faces.first;
        final painter = LivenessDetectionPainter(
          firstFace,
          inputImage.metadata!.size,
          inputImage.metadata!.rotation,
        );
        _customPaint = CustomPaint(
          painter: painter,
          child: Container(
            color: Colors.transparent,
            height: double.infinity,
            width: double.infinity,
          ),
        );
        if (_isProcessingStep &&
            _steps[_stepsKey.currentState?.currentIndex ?? 0].step ==
                LivenessDetectionStep.blink) {
          if (_didCloseEyes) {
            if ((faces.first.leftEyeOpenProbability ?? 1.0) < 0.75 &&
                (faces.first.rightEyeOpenProbability ?? 1.0) < 0.75) {
              _prosesCameraImage = true;

              await _completeStep(
                step: _steps[_stepsKey.currentState?.currentIndex ?? 0].step,
              );
            }
          }
        }
        _detect(
          face: faces.first,
          step: _steps[_stepsKey.currentState?.currentIndex ?? 0].step,
        );
      }
    } else {
      _resetSteps();
    }
    _isBusy = false;
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _completeStep({
    required LivenessDetectionStep step,
  }) async {
    final int indexToUpdate = _steps.indexWhere(
      (p0) => p0.step == step,
    );

    _steps[indexToUpdate] = _steps[indexToUpdate].copyWith(
      isCompleted: true,
    );
    if (mounted) {
      setState(() {});
    }
    await _stepsKey.currentState?.nextPage();
    _stopProcessing();
  }

  void _takePicture() async {
    try {
      if (_cameraController == null) return;
      if (_isTakingPicture) {
        return;
      }
      setState(() {
        _isTakingPicture = true;
      });
      await _cameraController?.stopImageStream();
      final XFile? clickedImage = await _cameraController?.takePicture();
      if (clickedImage == null) {
        _startLiveFeed();
        return;
      }
      _onDetectionCompleted(imgToReturn: clickedImage);
    } catch (e) {
      _startLiveFeed();
    }
  }

  void _onDetectionCompleted({
    XFile? imgToReturn,
  }) {
    final String? imgPath = imgToReturn?.path;
    if (imgPath == null) {
      Navigator.pop(context);
    }
    Navigator.of(context).pop(_cameraImage);
  }

  void _resetSteps() async {
    for (var p0 in _steps) {
      final int index = _steps.indexWhere(
        (p1) => p1.step == p0.step,
      );
      _steps[index] = _steps[index].copyWith(
        isCompleted: false,
      );
    }
    _customPaint = null;
    _didCloseEyes = false;
    if (_stepsKey.currentState?.currentIndex != 0) {
      _stepsKey.currentState?.reset();
    }
    if (mounted) {
      setState(() {});
    }
  }

  String _buildLoadingText(int count) {
    // Membangun teks loading dengan titik-titik berdasarkan nilai count
    String dots = '.' * count;
    return 'Loading$dots';
  }

  void _startProcessing() {
    if (!mounted) {
      return;
    }
    setState(
      () => _isProcessingStep = true,
    );
  }

  void _stopProcessing() {
    if (!mounted) {
      return;
    }
    setState(
      () => _isProcessingStep = false,
    );
  }

  void _detect({
    required Face face,
    required LivenessDetectionStep step,
  }) async {
    if (_isProcessingStep) {
      return;
    }
    switch (step) {
      case LivenessDetectionStep.blink:
        final LivenessThresholdBlink? blinkThreshold =
            LivenessDetectionFlutterPlugin.instance.thresholdConfig
                .firstWhereOrNull(
          (p0) => p0 is LivenessThresholdBlink,
        ) as LivenessThresholdBlink?;
        if ((face.leftEyeOpenProbability ?? 1.0) <
                (blinkThreshold?.leftEyeProbability ?? 0.25) &&
            (face.rightEyeOpenProbability ?? 1.0) <
                (blinkThreshold?.rightEyeProbability ?? 0.25)) {
          _startProcessing();
          if (mounted) {
            setState(
              () => _didCloseEyes = true,
            );
          }
        }
        break;
      case LivenessDetectionStep.turnRight:
        final LivenessThresholdHead? headTurnThreshold =
            LivenessDetectionFlutterPlugin.instance.thresholdConfig
                .firstWhereOrNull(
          (p0) => p0 is LivenessThresholdHead,
        ) as LivenessThresholdHead?;
        if ((face.headEulerAngleY ?? 0) <
            (headTurnThreshold?.rotationAngle ?? -30)) {
          _startProcessing();
          await _completeStep(step: step);
        }
        break;
      case LivenessDetectionStep.turnLeft:
        final LivenessThresholdHead? headTurnThreshold =
            LivenessDetectionFlutterPlugin.instance.thresholdConfig
                .firstWhereOrNull(
          (p0) => p0 is LivenessThresholdHead,
        ) as LivenessThresholdHead?;
        if ((face.headEulerAngleY ?? 0) >
            (headTurnThreshold?.rotationAngle ?? 30)) {
          _startProcessing();
          await _completeStep(step: step);
        }
        break;
      case LivenessDetectionStep.lookUp:
        final LivenessThresholdHead? headTurnThreshold =
            LivenessDetectionFlutterPlugin.instance.thresholdConfig
                .firstWhereOrNull(
          (p0) => p0 is LivenessThresholdHead,
        ) as LivenessThresholdHead?;
        if ((face.headEulerAngleX ?? 0) >
            (headTurnThreshold?.rotationAngle ?? 20)) {
          _startProcessing();
          await _completeStep(step: step);
        }
        break;
      case LivenessDetectionStep.lookDown:
        final LivenessThresholdHead? headTurnThreshold =
            LivenessDetectionFlutterPlugin.instance.thresholdConfig
                .firstWhereOrNull(
          (p0) => p0 is LivenessThresholdHead,
        ) as LivenessThresholdHead?;
        if ((face.headEulerAngleX ?? 0) <
            (headTurnThreshold?.rotationAngle ?? -20)) {
          _startProcessing();
          await _completeStep(step: step);
        }
        break;
      case LivenessDetectionStep.smile:
        final LivenessThresholdSmile? smileThreshold =
            LivenessDetectionFlutterPlugin.instance.thresholdConfig
                .firstWhereOrNull(
          (p0) => p0 is LivenessThresholdSmile,
        ) as LivenessThresholdSmile?;
        if ((face.smilingProbability ?? 0) >
            (smileThreshold?.probability ?? 0.75)) {
          _startProcessing();
          await _completeStep(step: step);
        }
        break;
    }
  }

  Widget _buildBody() {
    return Stack(
      children: [
        _isInfoStepCompleted
            ? _buildDetectionBody()
            : LivenessDetectionTutorialScreen(
                onStartTap: () {
                  if (mounted) {
                    setState(
                      () => _isInfoStepCompleted = true,
                    );
                  }
                  _startLiveFeed();
                },
              ),
        // Align(
        //   alignment: Alignment.topRight,
        //   child: Padding(
        //     padding: const EdgeInsets.only(
        //       right: 10,
        //       top: 10,
        //     ),
        //     child: CircleAvatar(
        //       radius: 20,
        //       backgroundColor: Colors.black,
        //       child: IconButton(
        //         onPressed: () => _onDetectionCompleted(
        //           imgToReturn: null,
        //         ),
        //         icon: const Icon(
        //           Icons.close_rounded,
        //           size: 20,
        //           color: Colors.white,
        //         ),
        //       ),
        //     ),
        //   ),
        // ),
      ],
    );
  }

  Widget _buildDetectionBody() {
    if (_cameraController == null ||
        _cameraController?.value.isInitialized == false) {
      return Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: MediaQuery.of(context).size.width / 3,
              padding: EdgeInsets.all(6),
              decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.80),
                  borderRadius: BorderRadius.circular(8)),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Center(
                      child: CircularProgressIndicator(
                    color: Colors.green,
                  )),
                  AnimatedBuilder(
                    animation: animation!,
                    builder: (context, child) {
                      return Container(
                        // width: MediaQuery.of(context).size.width / 3,
                        // padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                        // decoration: BoxDecoration(
                        //     color: Colors.green.withOpacity(0.65),
                        //     borderRadius: BorderRadius.circular(8)),
                        child: Text(
                          _buildLoadingText((animation!.value / 2).toInt()),
                          style: TextStyle(
                            fontSize: 20,
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }
    final size = MediaQuery.of(context).size;
    var scale = size.aspectRatio * _cameraController!.value.aspectRatio;
    if (scale < 1) scale = 1 / scale;
    final Widget cameraView = CameraPreview(_cameraController!);
    return Stack(
      fit: StackFit.expand,
      children: [
        Center(
          child: cameraView,
        ),
        BackdropFilter(
          filter: ui.ImageFilter.blur(
            sigmaX: 5.0,
            sigmaY: 5.0,
          ),
          child: Container(
            color: Colors.transparent,
            width: double.infinity,
            height: double.infinity,
          ),
        ),
        Center(
          child: Stack(
            children: [
              cameraView,
              SizedBox(
                width: MediaQuery.of(context).size.width,
                height: MediaQuery.of(context).size.width *
                    _cameraController!.value.aspectRatio,
                child: CustomPaint(
                  size: Size(
                    MediaQuery.of(context).size.width,
                    MediaQuery.of(context).size.width *
                        _cameraController!.value.aspectRatio,
                  ),
                  painter: TransparentCirclePainter(
                      color: _customPaint != null
                          ? Colors.white
                          : Colors.red.shade200),
                ),
                // child: Image.asset(
                //   'assets/layer.png',
                //   fit: BoxFit.cover,
                // ),
              ),
            ],
          ),
        ),
        // if (_customPaint != null)
        //   Center(
        //     child: Text("ADA WAJAH"),
        //   ),
        if (_customPaint == null)
          Positioned(
            bottom: 48,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                  color: Colors.red, borderRadius: BorderRadius.circular(8)),
              child: Text(
                "Wajah Anda Tidak Terdeteksi",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white),
              ),
            ),
          ),
        // if (_customPaint != null)
        //   Center(
        //       child: Container(
        //           // width: double.infinity,
        //           // height: double.infinity,
        //           child: CustomPaint(
        //               size: Size(
        //                   MediaQuery.of(context).size.width,
        //                   MediaQuery.of(context).size.width *
        //                       _cameraController!.value.aspectRatio),
        //               painter: CircularHolePainter()))),
        // if (_customPaint == null)
        //   Center(
        //       child: Container(
        //           // width: double.infinity,
        //           // height: double.infinity,
        //           child: CustomPaint(
        //               size: Size(
        //                   MediaQuery.of(context).size.width,
        //                   MediaQuery.of(context).size.width *
        //                       _cameraController!.value.aspectRatio),
        //               painter: CircularHolePainterFalse()))),
        LivenessDetectionStepOverlay(
          key: _stepsKey,
          steps: _steps,
          onCompleted: () => Future.delayed(
            const Duration(milliseconds: 500),
            () => _takePicture(),
          ),
        ),
      ],
    );
  }
}

class CircularHolePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    Paint paint = Paint()
      ..color = Colors.grey.withOpacity(0.5)
      ..style = PaintingStyle.fill;

    Rect outerRect = Offset.zero & size;
    Offset center = size.center(Offset.zero);
    double radius = size.width / 2.2;

    // Draw the outer rectangle
    Path path = Path()
      ..addRect(outerRect)
      ..addOval(Rect.fromCircle(center: center, radius: radius))
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(path, paint);

    // Draw the circular border
    Paint borderPaint = Paint()
      ..color = Colors.green // Change this to the desired border color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0; // Change this to the desired border width

    // Create a circle path for the border
    Path borderPath = Path()
      ..addOval(Rect.fromCircle(center: center, radius: radius))
      ..fillType = PathFillType.nonZero;

    canvas.drawPath(borderPath, borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}

class CircularHolePainterFalse extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    Paint paint = Paint()
      ..color = Colors.grey.withOpacity(0.5)
      ..style = PaintingStyle.fill;

    Rect outerRect = Offset.zero & size;
    Offset center = size.center(Offset.zero);
    double radius = size.width / 2.2;

    // Draw the outer rectangle
    Path path = Path()
      ..addRect(outerRect)
      ..addOval(Rect.fromCircle(center: center, radius: radius))
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(path, paint);

    // Draw the circular border
    Paint borderPaint = Paint()
      ..color = Colors.red // Change this to the desired border color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0; // Change this to the desired border width

    // Create a circle path for the border
    Path borderPath = Path()
      ..addOval(Rect.fromCircle(center: center, radius: radius))
      ..fillType = PathFillType.nonZero;

    canvas.drawPath(borderPath, borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}

class TransparentCirclePainter extends CustomPainter {
  final Color color;

  TransparentCirclePainter({super.repaint, required this.color});
  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = Colors.black.withOpacity(0.5) // Opacity for outer area
      ..style = PaintingStyle.fill;

    final Rect outerRect = Offset.zero & size;
    final Offset center = size.center(Offset.zero);
    final double radius = size.width / 2.2;

    // Draw the outer rectangle
    final Path path = Path()
      ..addRect(outerRect)
      ..addOval(Rect.fromCircle(center: center, radius: radius))
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(path, paint);

    // Draw the circular border
    final Paint borderPaint = Paint()
      ..color = color // Border color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0; // Border width

    final Path borderPath = Path()
      ..addOval(Rect.fromCircle(center: center, radius: radius))
      ..fillType = PathFillType.nonZero;

    canvas.drawPath(borderPath, borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}
