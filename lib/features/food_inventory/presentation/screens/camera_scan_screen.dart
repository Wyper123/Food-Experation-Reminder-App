import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:food_expiration_reminder/core/constants/app_colors.dart';
import 'package:food_expiration_reminder/core/constants/app_text_styles.dart';
import 'package:food_expiration_reminder/core/utils/date_formatter.dart';
import 'package:food_expiration_reminder/core/widgets/custom_button.dart';
import 'package:food_expiration_reminder/core/widgets/skeleton_loader.dart';
import 'package:food_expiration_reminder/features/food_inventory/scanning/expiry_date_parser.dart';
import 'package:food_expiration_reminder/features/food_inventory/scanning/text_scanner.dart';
import 'package:image_picker/image_picker.dart';

enum _CameraState { starting, ready, denied, unavailable }

/// Reads an expiration date off a package (Feature 13): live camera or a
/// gallery photo → on-device text recognition → the user confirms a date.
/// Pops with the confirmed [DateTime]; nothing is filled in without it.
class CameraScanScreen extends StatefulWidget {
  const CameraScanScreen({super.key});

  @override
  State<CameraScanScreen> createState() => _CameraScanScreenState();
}

class _CameraScanScreenState extends State<CameraScanScreen>
    with WidgetsBindingObserver {
  static const double _frameCenter = 0.42;

  /// A camera that never starts must not leave the user on a loading screen.
  static const Duration _startTimeout = Duration(seconds: 8);

  final TextScanner? _scanner =
      TextScanner.isSupported ? MlKitTextScanner() : null;
  CameraController? _camera;
  _CameraState _state = _CameraState.starting;
  bool _torch = false;
  bool _reading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _camera?.dispose();
    // Best-effort cleanup; failing to release the recognizer is harmless.
    _scanner?.close().ignore();
    super.dispose();
  }

  /// The camera must be released while the app is in the background.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final camera = _camera;
    if (state == AppLifecycleState.inactive && camera != null) {
      // Detach the preview first so nothing renders a disposed controller.
      setState(() {
        _camera = null;
        _torch = false;
      });
      camera.dispose();
    } else if (state == AppLifecycleState.resumed && _camera == null) {
      _startCamera();
    }
  }

  Future<void> _startCamera() async {
    if (_scanner == null) {
      setState(() => _state = _CameraState.unavailable);
      return;
    }
    try {
      final cameras = await availableCameras().timeout(_startTimeout);
      if (cameras.isEmpty) {
        if (mounted) setState(() => _state = _CameraState.unavailable);
        return;
      }
      final back = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final camera = CameraController(
        back,
        ResolutionPreset.high,
        enableAudio: false,
      );
      try {
        await camera.initialize().timeout(_startTimeout);
      } catch (_) {
        await camera.dispose();
        rethrow;
      }
      await camera.setFlashMode(FlashMode.off);
      if (!mounted) {
        await camera.dispose();
        return;
      }
      setState(() {
        _camera = camera;
        _torch = false;
        _state = _CameraState.ready;
      });
    } catch (e) {
      debugPrint('Camera failed: $e');
      if (!mounted) return;
      final denied =
          e is CameraException && e.code.startsWith('CameraAccessDenied');
      setState(
        () => _state = denied ? _CameraState.denied : _CameraState.unavailable,
      );
    }
  }

  Future<void> _toggleTorch() async {
    final camera = _camera;
    if (camera == null) return;
    final on = !_torch;
    await camera.setFlashMode(on ? FlashMode.torch : FlashMode.off);
    setState(() => _torch = on);
  }

  Future<void> _capture() async {
    final camera = _camera;
    if (camera == null || _reading) return;
    final XFile photo;
    try {
      photo = await camera.takePicture();
    } on CameraException catch (e) {
      debugPrint('Capture failed: ${e.code}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not take the photo. Try again.')),
        );
      }
      return;
    }
    await _read(photo.path, deleteAfter: true);
  }

  Future<void> _pickFromGallery() async {
    if (_reading) return;
    final photo = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (photo != null) await _read(photo.path, deleteAfter: false);
  }

  Future<void> _read(String path, {required bool deleteAfter}) async {
    setState(() => _reading = true);
    List<DateCandidate> found;
    try {
      final text = await _scanner!.readText(path);
      found = findExpiryDates(text, today: DateTime.now());
    } catch (e) {
      debugPrint('Text recognition failed: $e');
      found = const [];
    } finally {
      // Our own capture is a temporary file; gallery photos are the user's.
      if (deleteAfter) File(path).delete().ignore();
      if (mounted) setState(() => _reading = false);
    }
    if (!mounted) return;

    final result = await showModalBottomSheet<_ScanResult>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ResultSheet(candidates: found.take(3).toList()),
    );
    if (!mounted || result == null) return;
    switch (result) {
      case _UseDate(:final date):
        Navigator.of(context).pop(date);
      case _PickManually():
        await _pickManually();
      case _Retry():
        break;
    }
  }

  Future<void> _pickManually() async {
    final now = DateUtils.dateOnly(DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 5),
    );
    if (picked != null && mounted) Navigator.of(context).pop(picked);
  }

  @override
  Widget build(BuildContext context) {
    final camera = _camera;
    return Scaffold(
      backgroundColor: Colors.black,
      body: LayoutBuilder(
        builder: (context, c) {
          final frameBottom = c.maxHeight * _frameCenter + 65;
          return Stack(
            fit: StackFit.expand,
            children: [
              if (_state == _CameraState.ready && camera != null)
                _CoverPreview(camera: camera)
              else
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF1F2A25), Color(0xFF0B0F0D)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
              if (_state == _CameraState.starting)
                const SkeletonLoader(
                  baseColor: Color(0xFF1C1F1D),
                  highlightColor: Color(0xFF2C312E),
                  child: SkeletonBox(radius: 0, height: double.infinity),
                )
              else if (_state == _CameraState.ready) ...[
                CustomPaint(
                  painter: _ViewfinderPainter(centerYFactor: _frameCenter),
                ),
                Positioned(
                  left: 24,
                  right: 24,
                  top: frameBottom + 24,
                  child: Text(
                    _reading
                        ? 'Reading the date…'
                        : 'Align the printed expiration date inside the frame',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.subtitle.copyWith(color: Colors.white),
                  ),
                ),
              ] else
                _NoCamera(
                  denied: _state == _CameraState.denied,
                  canScanPhotos: _scanner != null,
                  onRetry: () {
                    setState(() => _state = _CameraState.starting);
                    _startCamera();
                  },
                  onPickPhoto: _pickFromGallery,
                  onPickManually: _pickManually,
                ),
              if (_reading)
                const Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: SkeletonLoader(
                    baseColor: Color(0x3312A072),
                    highlightColor: AppColors.emerald,
                    child: SkeletonBox(height: 4, radius: 0),
                  ),
                ),
              SafeArea(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    children: [
                      IconButton(
                        tooltip: 'Close',
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close_rounded,
                            color: Colors.white),
                      ),
                      Expanded(
                        child: Text(
                          'Scan expiration date',
                          textAlign: TextAlign.center,
                          style:
                              AppTextStyles.title.copyWith(color: Colors.white),
                        ),
                      ),
                      IconButton(
                        tooltip: _torch ? 'Turn off light' : 'Turn on light',
                        onPressed:
                            _state == _CameraState.ready ? _toggleTorch : null,
                        icon: Icon(
                          _torch
                              ? Icons.flash_on_rounded
                              : Icons.flash_off_rounded,
                          color: _state == _CameraState.ready
                              ? Colors.white
                              : Colors.white38,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (_state == _CameraState.ready)
                Align(
                  alignment: Alignment.bottomCenter,
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 28),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          IconButton(
                            tooltip: 'Scan a photo',
                            onPressed: _reading ? null : _pickFromGallery,
                            icon: const Icon(
                              Icons.photo_library_outlined,
                              color: Colors.white,
                              size: 28,
                            ),
                          ),
                          Semantics(
                            button: true,
                            label: 'Take photo',
                            child: GestureDetector(
                              onTap: _reading ? null : _capture,
                              child: Container(
                                width: 76,
                                height: 76,
                                padding: const EdgeInsets.all(5),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border:
                                      Border.all(color: Colors.white, width: 4),
                                ),
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: _reading
                                        ? Colors.white24
                                        : Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Enter date manually',
                            onPressed: _reading ? null : _pickManually,
                            icon: const Icon(
                              Icons.edit_calendar_outlined,
                              color: Colors.white,
                              size: 28,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// Fills the screen with the preview, cropping instead of letterboxing.
class _CoverPreview extends StatelessWidget {
  const _CoverPreview({required this.camera});

  final CameraController camera;

  @override
  Widget build(BuildContext context) {
    final size = camera.value.previewSize;
    if (size == null) return const SizedBox.expand();
    return ClipRect(
      child: FittedBox(
        fit: BoxFit.cover,
        // previewSize is reported in landscape; the screen is portrait.
        child: SizedBox(
          width: size.height,
          height: size.width,
          child: CameraPreview(camera),
        ),
      ),
    );
  }
}

class _NoCamera extends StatelessWidget {
  const _NoCamera({
    required this.denied,
    required this.canScanPhotos,
    required this.onRetry,
    required this.onPickPhoto,
    required this.onPickManually,
  });

  final bool denied;
  final bool canScanPhotos;
  final VoidCallback onRetry;
  final VoidCallback onPickPhoto;
  final VoidCallback onPickManually;

  @override
  Widget build(BuildContext context) {
    final message = !canScanPhotos
        ? 'Scanning works on Android and iOS phones. You can still enter '
            'the date yourself.'
        : denied
            ? 'Camera access is off. Allow it in your phone settings, or '
                'scan a photo from your gallery instead.'
            : 'The camera could not be started. You can scan a photo from '
                'your gallery instead.';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.no_photography_outlined,
              size: 64,
              color: Colors.white54,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTextStyles.body.copyWith(color: Colors.white),
            ),
            const SizedBox(height: 24),
            if (canScanPhotos) ...[
              CustomButton(
                label: 'Scan a photo',
                icon: Icons.photo_library_outlined,
                onPressed: onPickPhoto,
              ),
              const SizedBox(height: 10),
              if (denied)
                CustomButton(
                  label: 'Try camera again',
                  variant: CustomButtonVariant.secondary,
                  onPressed: onRetry,
                ),
            ],
            CustomButton(
              label: 'Enter date manually',
              variant: CustomButtonVariant.text,
              onPressed: onPickManually,
            ),
          ],
        ),
      ),
    );
  }
}

sealed class _ScanResult {
  const _ScanResult();
}

class _UseDate extends _ScanResult {
  const _UseDate(this.date);
  final DateTime date;
}

class _PickManually extends _ScanResult {
  const _PickManually();
}

class _Retry extends _ScanResult {
  const _Retry();
}

class _ResultSheet extends StatefulWidget {
  const _ResultSheet({required this.candidates});

  final List<DateCandidate> candidates;

  @override
  State<_ResultSheet> createState() => _ResultSheetState();
}

class _ResultSheetState extends State<_ResultSheet> {
  late DateCandidate? _selected = widget.candidates.firstOrNull;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final found = widget.candidates.isNotEmpty;
    final today = DateUtils.dateOnly(DateTime.now());
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              !found
                  ? 'No date found'
                  : widget.candidates.length == 1
                      ? 'Detected expiration date'
                      : 'Which date is the expiry?',
              style: AppTextStyles.title,
            ),
            const SizedBox(height: 8),
            if (!found)
              Text(
                'Try again closer to the date, with more light, or enter '
                'it yourself.',
                style: AppTextStyles.body.copyWith(color: cs.onSurfaceVariant),
              )
            else ...[
              for (final c in widget.candidates)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _CandidateTile(
                    candidate: c,
                    daysLeft: c.date.difference(today).inDays,
                    selected: identical(c, _selected),
                    onTap: () => setState(() => _selected = c),
                  ),
                ),
              Text(
                'Check this against the package before saving.',
                style: AppTextStyles.caption.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: CustomButton(
                    label: 'Retake',
                    variant: CustomButtonVariant.secondary,
                    onPressed: () => Navigator.of(context).pop(const _Retry()),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: found
                      ? CustomButton(
                          label: 'Use this date',
                          onPressed: () => Navigator.of(context)
                              .pop(_UseDate(_selected!.date)),
                        )
                      : CustomButton(
                          label: 'Enter manually',
                          onPressed: () =>
                              Navigator.of(context).pop(const _PickManually()),
                        ),
                ),
              ],
            ),
            if (found)
              CustomButton(
                label: 'None of these — enter manually',
                variant: CustomButtonVariant.text,
                onPressed: () =>
                    Navigator.of(context).pop(const _PickManually()),
              ),
          ],
        ),
      ),
    );
  }
}

class _CandidateTile extends StatelessWidget {
  const _CandidateTile({
    required this.candidate,
    required this.daysLeft,
    required this.selected,
    required this.onTap,
  });

  final DateCandidate candidate;
  final int daysLeft;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: selected ? cs.primary.withValues(alpha: 0.12) : null,
          border: Border.all(
            color: selected ? cs.primary : cs.outlineVariant,
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    DateFormatter.short(candidate.date),
                    style: AppTextStyles.headline.copyWith(fontSize: 20),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Read as "${candidate.source.trim()}" · '
                    '${DateFormatter.daysLabel(daysLeft)}',
                    style: AppTextStyles.caption.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (selected) Icon(Icons.check_circle_rounded, color: cs.primary),
          ],
        ),
      ),
    );
  }
}

class _ViewfinderPainter extends CustomPainter {
  _ViewfinderPainter({required this.centerYFactor});

  final double centerYFactor;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height * centerYFactor),
      width: size.width * 0.82,
      height: 130,
    );
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(18));

    final dim = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addRRect(rrect);
    canvas.drawPath(dim, Paint()..color = Colors.black.withValues(alpha: 0.6));

    final p = Paint()
      ..color = AppColors.emerald
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    const len = 26.0;
    void corner(Offset c, double dx, double dy) {
      canvas.drawLine(c, c + Offset(dx * len, 0), p);
      canvas.drawLine(c, c + Offset(0, dy * len), p);
    }

    corner(rect.topLeft, 1, 1);
    corner(rect.topRight, -1, 1);
    corner(rect.bottomLeft, 1, -1);
    corner(rect.bottomRight, -1, -1);
  }

  @override
  bool shouldRepaint(covariant _ViewfinderPainter old) =>
      old.centerYFactor != centerYFactor;
}
