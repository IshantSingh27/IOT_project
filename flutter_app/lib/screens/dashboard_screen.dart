import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/app_colors.dart';
import '../constants/api_constants.dart';
import '../providers/auth_provider.dart';
import '../providers/security_provider.dart';
import '../widgets/door_lock_button.dart';
import '../widgets/telemetry_badge.dart';
import '../widgets/mjpeg_stream_view.dart';
import '../widgets/event_tile.dart';
import 'live_stream_screen.dart';
import 'activity_logs_screen.dart';
import 'authorized_faces_screen.dart';
import 'settings_screen.dart';
import 'login_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final sec = Provider.of<SecurityProvider>(context);
    final streamUrl = "${sec.baseUrl}${ApiConstants.videoStream}";

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.shield_outlined, color: AppColors.primary, size: 20),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "HOME SECURITY",
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
                Text(
                  auth.currentUser?.fullName ?? "Ishant (Owner)",
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.face_retouching_natural_rounded, color: AppColors.primary),
            tooltip: "Authorized Faces",
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AuthorizedFacesScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.history_rounded, color: AppColors.textPrimary),
            tooltip: "Activity Logs",
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ActivityLogsScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: AppColors.textSecondary),
            tooltip: "Settings",
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: AppColors.alertRed),
            tooltip: "Logout",
            onPressed: () async {
              await auth.logout();
              if (context.mounted) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                );
              }
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => sec.fetchInitialData(),
        color: AppColors.primary,
        backgroundColor: AppColors.surface,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Real-Time Alert Banner
              if (sec.latestAlert != null) ...[
                _buildRealtimeAlertBanner(context, sec),
                const SizedBox(height: 16),
              ],

              // Hero Lock / Unlock Section
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: sec.status.doorLocked
                        ? AppColors.alertRed.withOpacity(0.3)
                        : AppColors.safeGreen.withOpacity(0.3),
                    width: 1.5,
                  ),
                ),
                child: Column(
                  children: [
                    DoorLockButton(
                      isLocked: sec.status.doorLocked,
                      isBusy: sec.isDoorBusy,
                      onToggle: () => sec.toggleDoor(),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      sec.status.doorLocked
                          ? "Door is securely locked"
                          : "Door is currently unlocked",
                      style: TextStyle(
                        color: sec.status.doorLocked
                            ? AppColors.alertRedLight
                            : AppColors.safeGreenLight,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // IoT Telemetry Status Row
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    TelemetryBadge(
                      icon: Icons.directions_walk_rounded,
                      title: "PIR Sensor",
                      value: sec.status.pirActive ? "MOTION DETECTED" : "CLEAR / IDLE",
                      activeColor: AppColors.motionAmber,
                      isActive: sec.status.pirActive,
                    ),
                    const SizedBox(width: 10),
                    TelemetryBadge(
                      icon: Icons.remove_red_eye_rounded,
                      title: "Face AI",
                      value: sec.status.faceRecognitionActive ? "ACTIVE SCANNING" : "SLEEP (0% CPU)",
                      activeColor: AppColors.primary,
                      isActive: sec.status.faceRecognitionActive,
                    ),
                    const SizedBox(width: 10),
                    TelemetryBadge(
                      icon: Icons.usb_rounded,
                      title: "Arduino Link",
                      value: sec.status.serialConnected ? "CONNECTED" : "SIMULATED",
                      activeColor: AppColors.safeGreen,
                      isActive: sec.status.serialConnected,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Developer PIR Simulator Card (Allows instant hardware-less testing!)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.smart_toy_outlined, color: AppColors.primary, size: 20),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        "Test PIR Trigger:",
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () => sec.simulatePirMotion(true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.motionAmber.withOpacity(0.2),
                        foregroundColor: AppColors.motionAmber,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        minimumSize: const Size(60, 32),
                      ),
                      child: const Text("Trigger PIR", style: TextStyle(fontSize: 11)),
                    ),
                    const SizedBox(width: 6),
                    ElevatedButton(
                      onPressed: () => sec.simulatePirMotion(false),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.surface,
                        foregroundColor: AppColors.textMuted,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        minimumSize: const Size(60, 32),
                      ),
                      child: const Text("Clear PIR", style: TextStyle(fontSize: 11)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Live Camera Stream Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: AppColors.alertRed,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        "LIVE CAMERA FEED",
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ],
                  ),
                  TextButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const LiveStreamScreen()),
                      );
                    },
                    icon: const Icon(Icons.fullscreen_rounded, color: AppColors.primary, size: 18),
                    label: const Text(
                      "Fullscreen",
                      style: TextStyle(color: AppColors.primary, fontSize: 12),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Stream Player Card
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const LiveStreamScreen()),
                  );
                },
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    height: 220,
                    width: double.infinity,
                    color: AppColors.surface,
                    child: Stack(
                      children: [
                        MjpegStreamView(
                          streamUrl: streamUrl,
                          width: double.infinity,
                          height: 220,
                        ),
                        // Corner badge
                        Positioned(
                          top: 10,
                          right: 10,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.7),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.videocam_rounded, color: AppColors.safeGreen, size: 14),
                                SizedBox(width: 4),
                                Text(
                                  "FRONT DOOR",
                                  style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Recent Activity Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "RECENT ACTIVITY",
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      letterSpacing: 1.0,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const ActivityLogsScreen()),
                      );
                    },
                    child: const Text("View All", style: TextStyle(color: AppColors.primary, fontSize: 12)),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              if (sec.logs.isEmpty)
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Center(
                    child: Text(
                      "No security events recorded yet.",
                      style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                    ),
                  ),
                )
              else
                ...sec.logs.take(4).map((event) => EventTile(event: event, baseUrl: sec.baseUrl)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRealtimeAlertBanner(BuildContext context, SecurityProvider sec) {
    final alert = sec.latestAlert!;
    final isIntruder = alert['type'] == 'INTRUDER_ALERT';
    final isAccess = alert['type'] == 'ACCESS_GRANTED';
    final color = isIntruder ? AppColors.alertRed : (isAccess ? AppColors.safeGreen : AppColors.primary);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.18),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color, width: 1.5),
      ),
      child: Row(
        children: [
          Icon(
            isIntruder ? Icons.warning_amber_rounded : Icons.notifications_active_rounded,
            color: color,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  alert['title'] ?? 'Security Alert',
                  style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13),
                ),
                Text(
                  alert['message'] ?? '',
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 12),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: AppColors.textMuted, size: 18),
            onPressed: () => sec.clearLatestAlert(),
          ),
        ],
      ),
    );
  }
}
