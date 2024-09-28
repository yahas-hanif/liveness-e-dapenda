import 'package:liveness_detection_flutter_plugin/index.dart';

class LivenessDetectionStepOverlay extends StatefulWidget {
  final List<LivenessDetectionStepItem> steps;
  final VoidCallback onCompleted;
  const LivenessDetectionStepOverlay(
      {super.key, required this.steps, required this.onCompleted});

  @override
  State<LivenessDetectionStepOverlay> createState() =>
      LivenessDetectionStepOverlayState();
}

class LivenessDetectionStepOverlayState
    extends State<LivenessDetectionStepOverlay>
    with SingleTickerProviderStateMixin {
  AnimationController? controller;
  Animation<double>? animation;

  int get currentIndex {
    return _currentIndex;
  }

  bool _isLoading = false;

  //* MARK: - Private Variables
  //? =========================================================
  int _currentIndex = 0;

  late final PageController _pageController;

  //* MARK: - Life Cycle Methods
  //? =========================================================
  @override
  void initState() {
    controller = AnimationController(
      vsync: this,
      duration: Duration(seconds: 2),
    );

    animation = Tween<double>(
      begin: 0.0,
      end: 2 * 3.141592653589793, // 2π radians (full circle)
    ).animate(controller!);

    controller!.repeat();

    // Memulai animasi
    // controller!.forward();
    _pageController = PageController(
      initialPage: 0,
    );
    super.initState();
  }

  String _buildLoadingText(int count) {
    // Membangun teks loading dengan titik-titik berdasarkan nilai count
    String dots = '.' * count;
    return 'Loading$dots';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: double.infinity,
      width: double.infinity,
      color: Colors.transparent,
      child: Stack(
        fit: StackFit.expand,
        children: [
          _buildBody(),
          Visibility(
            visible: _isLoading,
            child: Center(
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
                                _buildLoadingText(
                                    (animation!.value / 2).toInt()),
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
            ),
          )
        ],
      ),
    );
  }

  Future<void> nextPage() async {
    if (_isLoading) {
      return;
    }
    if ((_currentIndex + 1) <= (widget.steps.length - 1)) {
      //Move to next step
      _showLoader();
      await Future.delayed(
        const Duration(
          milliseconds: 500,
        ),
      );
      await _pageController.nextPage(
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeIn,
      );
      await Future.delayed(
        const Duration(seconds: 2),
      );
      _hideLoader();
      setState(() => _currentIndex++);
    } else {
      widget.onCompleted();
    }
  }

  void reset() {
    _pageController.jumpToPage(0);
    setState(() => _currentIndex = 0);
  }

  //* MARK: - Private Methods for Business Logic
  //? =========================================================
  void _showLoader() => setState(
        () => _isLoading = true,
      );

  void _hideLoader() => setState(
        () => _isLoading = false,
      );

  //* MARK: - Private Methods for UI Components
  //? =========================================================
  Widget _buildBody() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 10,
          width: double.infinity,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Expanded(
                flex: _currentIndex + 1,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(20),
                      bottomRight: Radius.circular(20),
                    ),
                    color: Colors.green.shade800,
                  ),
                ),
              ),
              Expanded(
                flex: widget.steps.length - (_currentIndex + 1),
                child: Container(
                  color: Colors.transparent,
                ),
              ),
            ],
          ),
        ),
        const Spacer(),
        Flexible(
          flex: 2,
          child: AbsorbPointer(
            absorbing: true,
            child: PageView.builder(
              controller: _pageController,
              itemCount: widget.steps.length,
              itemBuilder: (context, index) {
                return _buildAnimatedWidget(
                  Padding(
                    padding: const EdgeInsets.all(10),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: const [
                          BoxShadow(
                            blurRadius: 5,
                            spreadRadius: 2.5,
                            color: Colors.black12,
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      margin: const EdgeInsets.symmetric(horizontal: 30),
                      padding: const EdgeInsets.all(10),
                      child: Text(
                        widget.steps[index].title,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  isExiting: index != _currentIndex,
                );
              },
            ),
          ),
        ),
        const Spacer(
          flex: 14,
        ),
      ],
    );
  }

  Widget _buildAnimatedWidget(
    Widget child, {
    required bool isExiting,
  }) {
    return isExiting
        ? ZoomOut(
            animate: true,
            child: FadeOutLeft(
              animate: true,
              delay: const Duration(milliseconds: 200),
              child: child,
            ),
          )
        : ZoomIn(
            animate: true,
            delay: const Duration(milliseconds: 500),
            child: FadeInRight(
              animate: true,
              delay: const Duration(milliseconds: 700),
              child: child,
            ),
          );
  }
}
