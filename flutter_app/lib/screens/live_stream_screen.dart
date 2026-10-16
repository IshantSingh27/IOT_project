import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/app_colors.dart';
import '../constants/api_constants.dart';
import '../providers/security_provider.dart';
import '../widgets/mjpeg_stream_view.dart';

class LiveStreamScreen extends StatelessWidget {
  const LiveStreamScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final sec = Provider.of<SecurityProvider>(context);
    final streamUrl = "${sec.baseUrl}${ApiConstants.videoStream}";

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: const Text(
          "CAMERA 01 - LIVE SURVEILLANCE",
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.alertRed.withOpacity(0.2),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppColors.alertRed),
            ),
            child: const Row(
              children: [
                Icon(Icons.fiber_manual_record, color: AppColors.alertRed, size: 10),
                SizedBox(width: 4),
                Text("LIVE", style: TextStyle(color: AppColors.alertRed, fontSize: 10, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Expanded video viewer
          Expanded(
            child: Stack(
              children: [
                Center(
                  child: MjpegStreamView(
                    streamUrl: streamUrl,
                    fit: BoxFit.contain,
                    width: double.infinity,
                  ),
                ),

                // Corner crosshairs / HUD overlay
                Positioned(
                  top: 20,
                  left: 20,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "PIR: ${sec.status.pirActive ? 'MOTION ACTIVE' : 'CLEAR'}",
                          style: TextStyle(
                            color: sec.status.pirActive ? AppColors.motionAmber : AppColors.safeGreen,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          "AI VISION: ${sec.status.faceRecognitionActive ? 'FACE RECOGNITION ENGAGED' : 'STANDBY'}",
                          style: TextStyle(
                            color: sec.status.faceRecognitionActive ? AppColors.primary : AppColors.textMuted,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Bottom Control Deck
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            color: AppColors.surface,
            child: SafeArea(
              top: false,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  // Door Lock / Unlock Quick Action
                  ElevatedButton.icon(
                    onPressed: sec.isDoorBusy ? null : () => sec.toggleDoor(),
                    icon: Icon(
                      sec.status.doorLocked ? Icons.lock_open_rounded : Icons.lock_rounded,
                      size: 20,
                    ),
                    label: Text(sec.status.doorLocked ? "UNLOCK DOOR" : "LOCK DOOR"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: sec.status.doorLocked ? AppColors.safeGreen : AppColors.alertRed,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),

                  // Trigger PIR motion test
                  OutlinedButton.icon(
                    onPressed: () {
                      sec.simulatePirMotion(!sec.status.pirActive);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            sec.status.pirActive ? "Cleared PIR Motion" : "Simulated PIR Motion! Face AI Triggered",
                          ),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    },
                    icon: const Icon(Icons.motion_photos_on_rounded, size: 20),
                    label: Text(sec.status.pirActive ? "CLEAR PIR" : "TRIGGER PIR"),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.motionAmber,
                      side: const BorderSide(color: AppColors.motionAmber),
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
