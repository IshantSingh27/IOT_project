import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../constants/app_colors.dart';
import '../models/security_event_model.dart';

class EventTile extends StatelessWidget {
  final SecurityEventModel event;
  final String baseUrl;

  const EventTile({
    super.key,
    required this.event,
    required this.baseUrl,
  });

  Color _getEventColor() {
    switch (event.eventType) {
      case 'ACCESS_GRANTED':
        return AppColors.safeGreen;
      case 'INTRUDER_ALERT':
        return AppColors.alertRed;
      case 'MOTION':
        return AppColors.motionAmber;
      case 'MANUAL_UNLOCK':
        return AppColors.primary;
      default:
        return AppColors.textSecondary;
    }
  }

  IconData _getEventIcon() {
    switch (event.eventType) {
      case 'ACCESS_GRANTED':
        return Icons.verified_user_rounded;
      case 'INTRUDER_ALERT':
        return Icons.warning_amber_rounded;
      case 'MOTION':
        return Icons.directions_walk_rounded;
      case 'MANUAL_UNLOCK':
        return Icons.lock_open_rounded;
      default:
        return Icons.notifications_none_rounded;
    }
  }

  void _showSnapshotDialog(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    event.title,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppColors.textMuted),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    height: 200,
                    color: AppColors.surfaceLight,
                    child: const Center(
                      child: Text("Could not load snapshot", style: TextStyle(color: AppColors.textMuted)),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (event.description != null)
                Text(
                  event.description!,
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              const SizedBox(height: 8),
              Text(
                DateFormat('MMM dd, yyyy  hh:mm:ss a').format(event.timestamp),
                style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final color = _getEventColor();
    final timeStr = DateFormat('hh:mm a').format(event.timestamp);
    final dateStr = DateFormat('MMM dd').format(event.timestamp);
    final fullSnapshotUrl = (event.snapshotUrl != null && event.snapshotUrl!.isNotEmpty)
        ? "$baseUrl${event.snapshotUrl}"
        : null;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 2),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: event.isCritical ? AppColors.alertRed.withOpacity(0.6) : AppColors.border,
          width: event.isCritical ? 1.5 : 1.0,
        ),
      ),
      child: Row(
        children: [
          // Icon indicator
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(_getEventIcon(), color: color, size: 20),
          ),
          const SizedBox(width: 12),
          
          // Title & Description
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        event.title,
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: event.isCritical ? FontWeight.bold : FontWeight.w600,
                          fontSize: 14,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      "$dateStr, $timeStr",
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  event.description ?? event.eventType,
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          
          // Snapshot thumbnail if available
          if (fullSnapshotUrl != null) ...[
            const SizedBox(width: 10),
            GestureDetector(
              onTap: () => _showSnapshotDialog(context, fullSnapshotUrl),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: 44,
                  height: 44,
                  color: AppColors.surfaceLight,
                  child: Image.network(
                    fullSnapshotUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => const Icon(
                      Icons.image_not_supported_rounded,
                      size: 20,
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
