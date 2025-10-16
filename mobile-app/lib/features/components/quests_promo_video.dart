import 'package:flutter/material.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/shared/extensions/media_query_data_extension.dart';
import 'package:video_player/video_player.dart';

class QuestsPromoVideo extends StatefulWidget {
  final bool isSubmitting;
  final VoidCallback? closeSheet;
  final Function(bool isFinalVideo) setIsFinalVideo;
  final bool startFromBeginning;
  final bool showCloseButton;
  final bool isVisible;

  const QuestsPromoVideo({
    super.key,
    this.closeSheet,
    required this.isSubmitting,
    required this.setIsFinalVideo,
    this.startFromBeginning = false,
    this.showCloseButton = true,
    this.isVisible = true,
  });

  @override
  State<QuestsPromoVideo> createState() => _QuestsPromoVideoState();
}

class _QuestsPromoVideoState extends State<QuestsPromoVideo> {
  final SettingsService _settingsService = SettingsService();
  late VideoPlayerController _controller;
  int _currentStoryIndex = 0;

  final List<String> _storyVideos = [
    'assets/videos/quantus_quests_promo_1.mp4',
    'assets/videos/quantus_quests_promo_2.mp4',
    'assets/videos/quantus_quests_promo_3.mp4',
  ];

  @override
  void initState() {
    super.initState();

    setState(() {
      _currentStoryIndex = widget.startFromBeginning
          ? 0
          : (_settingsService.hasWatchedQuestsPromo() ? 2 : 0);
    });

    _initializeVideo(_currentStoryIndex);
  }

  @override
  void didUpdateWidget(QuestsPromoVideo oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Handle visibility changes
    if (oldWidget.isVisible != widget.isVisible) {
      if (widget.isVisible) {
        _playVideo();
      } else {
        _pauseVideo();
      }
    }
  }

  void _pauseVideo() {
    if (_controller.value.isInitialized && _controller.value.isPlaying) {
      _controller.pause();
    }
  }

  void _playVideo() {
    if (_controller.value.isInitialized && !_controller.value.isPlaying) {
      _controller.play();
    }
  }

  Future<void> _initializeVideo(int index) async {
    if (index < 0 || index >= _storyVideos.length) return;

    _controller = VideoPlayerController.asset(_storyVideos[index]);

    try {
      await _controller.initialize();
      setState(() {});
      _controller.play();
      widget.setIsFinalVideo(_currentStoryIndex == _storyVideos.length - 1);

      // Listen for video completion
      _controller.addListener(_videoListener);
    } catch (e) {
      print('Error initializing video: $e');
    }
  }

  void _videoListener() {
    if (_controller.value.position >= _controller.value.duration) {
      if (_currentStoryIndex == _storyVideos.length - 1) {
        _controller.seekTo(Duration.zero);
        _controller.play();
      } else {
        _nextStory();
      }
    }
    setState(() {});
  }

  void _nextStory() {
    if (_currentStoryIndex < _storyVideos.length - 1) {
      _controller.removeListener(_videoListener);
      _controller.dispose();
      _currentStoryIndex++;
      _initializeVideo(_currentStoryIndex);
    }
  }

  void _previousStory() {
    if (_currentStoryIndex > 0) {
      _controller.removeListener(_videoListener);
      _controller.dispose();
      _currentStoryIndex--;
      _initializeVideo(_currentStoryIndex);
    }
  }

  void _togglePlayPause() {
    setState(() {
      _controller.value.isPlaying ? _controller.pause() : _controller.play();
    });
  }

  @override
  void dispose() {
    _controller.removeListener(_videoListener);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (details) {
        final width = MediaQuery.of(context).size.width;
        if (details.globalPosition.dx < width / 3) {
          _previousStory();
        } else if (details.globalPosition.dx > 2 * width / 3) {
          _nextStory();
        } else {
          _togglePlayPause();
        }
      },
      child: Stack(
        children: [
          Center(
            child: AspectRatio(
              aspectRatio: _controller.value.aspectRatio,
              child: VideoPlayer(_controller),
            ),
          ),
          _buildStoryProgressBars(),
        ],
      ),
    );
  }

  Widget _buildStoryProgressBars() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // balance the spacing to make progress bar centered
            // by adding sized box same width + icon width
            SizedBox(width: 26 + (context.isTablet ? 28 : 24)),
            SizedBox(
              width: 258,
              child: Row(
                children: List.generate(
                  _storyVideos.length,
                  (index) => Expanded(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      height: 3,
                      decoration: BoxDecoration(
                        color: Colors.white.useOpacity(0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: _getProgressForStory(index),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 26),
            if (widget.showCloseButton && widget.closeSheet != null)
              InkWell(
                onTap: widget.isSubmitting ? null : widget.closeSheet,
                child: Icon(Icons.close, size: context.isTablet ? 28 : 24),
              ),
          ],
        ),
      ),
    );
  }

  double _getProgressForStory(int index) {
    if (index < _currentStoryIndex) {
      return 1.0;
    } else if (index == _currentStoryIndex) {
      if (_controller.value.duration.inMilliseconds > 0) {
        return _controller.value.position.inMilliseconds /
            _controller.value.duration.inMilliseconds;
      }
      return 0.0;
    } else {
      return 0.0;
    }
  }
}
