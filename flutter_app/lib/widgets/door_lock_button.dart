import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class DoorLockButton extends StatefulWidget {
  final bool isLocked;
  final bool isBusy;
  final VoidCallback onToggle;

  const DoorLockButton({
    super.key,
    required this.isLocked,
    required this.isBusy,
    required this.onToggle,
  });

  @override
  State<DoorLockButton> createState() => _DoorLockButtonState();
}

class _DoorLockButtonState extends State<DoorLockButton> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 0.96, end: 1.04).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activeColor = widget.isLocked ? AppColors.alertRed : AppColors.safeGreen;
    final activeColorLight = widget.isLocked ? AppColors.alertRedLight : AppColors.safeGreenLight;

    return Center(
      child: GestureDetector(
        onTap: widget.isBusy ? null : widget.onToggle,
        child: AnimatedBuilder(
          animation: _pulseController,
          builder: (context, child) {
            return Transform.scale(
              scale: widget.isLocked ? 1.0 : _scaleAnimation.value,
              child: Container(
                width: 170,
                height: 170,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      activeColor.withOpacity(0.25),
                      AppColors.surface,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  border: Border.all(
                    color: activeColor.withOpacity(0.8),
                    width: 3.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: activeColor.withOpacity(widget.isLocked ? 0.35 : 0.6),
                      blurRadius: widget.isLocked ? 20 : 35,
                      spreadRadius: widget.isLocked ? 2 : 6,
                    ),
                  ],
                ),
                child: Center(
                  child: widget.isBusy
                      ? CircularProgressIndicator(color: activeColor, strokeWidth: 3)
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              widget.isLocked
                                  ? Icons.lock_rounded
                                  : Icons.lock_open_rounded,
                              size: 46,
                              color: activeColorLight,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              widget.isLocked ? "DOOR LOCKED" : "DOOR UNLOCKED",
                              style: TextStyle(
                                color: activeColorLight,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.isLocked ? "Tap to unlock" : "Tap to lock",
                              style: TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 11,
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
    );
  }
}
