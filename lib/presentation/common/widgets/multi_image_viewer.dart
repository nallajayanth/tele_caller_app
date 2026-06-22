import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/constants/app_colors.dart';

class MultiImageViewerDialog extends StatefulWidget {
  final List<String> imageUrls;
  final int initialIndex;
  final String title;

  const MultiImageViewerDialog({
    super.key,
    required this.imageUrls,
    this.initialIndex = 0,
    this.title = 'Verification Photo',
  });

  static void show(
    BuildContext context, {
    required List<String> imageUrls,
    int initialIndex = 0,
    String title = 'Verification Photo',
  }) {
    if (imageUrls.isEmpty) return;
    showDialog(
      context: context,
      barrierColor: const Color(0xE6000000), // 90% black opacity
      builder: (_) => MultiImageViewerDialog(
        imageUrls: imageUrls,
        initialIndex: initialIndex,
        title: title,
      ),
    );
  }

  @override
  State<MultiImageViewerDialog> createState() => _MultiImageViewerDialogState();
}

class _MultiImageViewerDialogState extends State<MultiImageViewerDialog> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    HapticFeedback.selectionClick();
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // AppBar
          Container(
            decoration: const BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.title,
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'Photo ${_currentIndex + 1} of ${widget.imageUrls.length}',
                        style: GoogleFonts.plusJakartaSans(
                          color: AppColors.textTertiary,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Image Viewport
          Expanded(
            child: Container(
              color: Colors.black,
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: _onPageChanged,
                itemCount: widget.imageUrls.length,
                itemBuilder: (context, index) {
                  return InteractiveViewer(
                    minScale: 0.5,
                    maxScale: 3.5,
                    child: Center(
                      child: CachedNetworkImage(
                        imageUrl: widget.imageUrls[index],
                        fit: BoxFit.contain,
                        placeholder: (context, url) => const Center(
                          child: CircularProgressIndicator(
                            color: AppColors.primaryLight,
                          ),
                        ),
                        errorWidget: (context, url, error) => Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.error_outline_rounded,
                              color: AppColors.error,
                              size: 48,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Failed to load image',
                              style: GoogleFonts.plusJakartaSans(
                                color: Colors.white70,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          // Bottom Thumbnail bar (Only if multiple images)
          if (widget.imageUrls.length > 1)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
              decoration: const BoxDecoration(
                color: Color(0xD9000000), // 85% black opacity
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
              ),
              child: SizedBox(
                height: 56,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  shrinkWrap: true,
                  itemCount: widget.imageUrls.length,
                  itemBuilder: (context, index) {
                    final isSelected = index == _currentIndex;
                    return GestureDetector(
                      onTap: () {
                        if (_currentIndex != index) {
                          _pageController.animateToPage(
                            index,
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        }
                      },
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 6),
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSelected
                                ? AppColors.primaryLight
                                : Colors.transparent,
                            width: 2.5,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: CachedNetworkImage(
                            imageUrl: widget.imageUrls[index],
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(
                              color: Colors.white10,
                            ),
                            errorWidget: (context, url, error) => const Icon(
                              Icons.broken_image,
                              color: Colors.white24,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            )
          else
            Container(
              height: 16,
              decoration: const BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
              ),
            ),
        ],
      ),
    ).animate().fadeIn(duration: 250.ms).scale(begin: const Offset(0.92, 0.92), curve: Curves.easeOutBack);
  }
}
