import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import '../constants/app_colors.dart';
import '../providers/security_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _urlController;
  bool _isTesting = false;
  String? _testResult;

  @override
  void initState() {
    super.initState();
    final sec = Provider.of<SecurityProvider>(context, listen: false);
    _urlController = TextEditingController(text: sec.baseUrl);
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  void _testConnection() async {
    setState(() {
      _isTesting = true;
      _testResult = null;
    });

    final targetUrl = _urlController.text.trim();
    try {
      final res = await http.get(Uri.parse(targetUrl)).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        setState(() {
          _testResult = "Connection successful! Server responded with 200 OK.";
        });
      } else {
        setState(() {
          _testResult = "Server reachable, but returned status code: ${res.statusCode}";
        });
      }
    } catch (e) {
      setState(() {
        _testResult = "Connection failed: $e";
      });
    } finally {
      setState(() {
        _isTesting = false;
      });
    }
  }

  void _saveSettings() async {
    final sec = Provider.of<SecurityProvider>(context, listen: false);
    await sec.updateBaseUrl(_urlController.text.trim());
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Server settings saved successfully!")),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sec = Provider.of<SecurityProvider>(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: const Text(
          "SETTINGS & CONNECTIVITY",
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "BACKEND SERVER HOST",
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
                fontSize: 12,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              "Configure the IP address of the laptop running the FastAPI vision & IoT hub:",
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 14),

            TextField(
              controller: _urlController,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                filled: true,
                fillColor: AppColors.surface,
                prefixIcon: const Icon(Icons.dns_rounded, color: AppColors.primary),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.primary),
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Quick IP presets
            Wrap(
              spacing: 8,
              children: [
                ActionChip(
                  label: const Text("Localhost"),
                  onPressed: () => setState(() => _urlController.text = "http://127.0.0.1:8000"),
                  backgroundColor: AppColors.surface,
                  labelStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                ),
                ActionChip(
                  label: const Text("Android Emulator (10.0.2.2)"),
                  onPressed: () => setState(() => _urlController.text = "http://10.0.2.2:8000"),
                  backgroundColor: AppColors.surface,
                  labelStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Test Connection button
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: _isTesting ? null : _testConnection,
                  icon: _isTesting
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.wifi_tethering_rounded, size: 16),
                  label: const Text("Test Ping"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.surfaceLight,
                    foregroundColor: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _saveSettings,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.black,
                  ),
                  child: const Text("Save & Reconnect", style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            if (_testResult != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _testResult!.contains("successful") ? AppColors.safeGreen : AppColors.alertRed,
                  ),
                ),
                child: Text(
                  _testResult!,
                  style: TextStyle(
                    color: _testResult!.contains("successful") ? AppColors.safeGreenLight : AppColors.alertRedLight,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 32),

            const Text(
              "HARDWARE & SYSTEM TELEMETRY",
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
                fontSize: 12,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 12),

            _buildTelemetryTile("Camera Stream", sec.status.cameraOnline ? "Active" : "Simulated Feed", Icons.videocam),
            _buildTelemetryTile("Serial Controller", sec.status.serialConnected ? "Arduino USB Connected" : "Simulation Mode", Icons.usb),
            _buildTelemetryTile("Face AI Engine", sec.status.faceRecognitionActive ? "Processing" : "Sleeping (PIR gated)", Icons.psychology),
            _buildTelemetryTile("Auto-Lock Delay", "10 seconds (Hardware Timer)", Icons.timer_outlined),
          ],
        ),
      ),
    );
  }

  Widget _buildTelemetryTile(String title, String value, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary, size: 20),
          const SizedBox(width: 12),
          Text(title, style: const TextStyle(color: AppColors.textPrimary, fontSize: 13)),
          const Spacer(),
          Text(value, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
        ],
      ),
    );
  }
}
