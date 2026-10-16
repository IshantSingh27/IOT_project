import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../constants/app_colors.dart';
import '../providers/security_provider.dart';

class AuthorizedFacesScreen extends StatefulWidget {
  const AuthorizedFacesScreen({super.key});

  @override
  State<AuthorizedFacesScreen> createState() => _AuthorizedFacesScreenState();
}

class _AuthorizedFacesScreenState extends State<AuthorizedFacesScreen> {
  final ImagePicker _picker = ImagePicker();

  void _showAddFaceDialog() {
    final nameController = TextEditingController();
    String relationship = "Family";
    XFile? selectedImage;
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: AppColors.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text(
              "Enroll Authorized Face",
              style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Image preview / picker
                  GestureDetector(
                    onTap: () async {
                      final picked = await _picker.pickImage(
                        source: ImageSource.camera,
                        imageQuality: 85,
                      );
                      if (picked != null) {
                        setDialogState(() => selectedImage = picked);
                      }
                    },
                    child: Container(
                      width: 110,
                      height: 110,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceLight,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.primary, width: 2),
                      ),
                      child: selectedImage != null
                          ? ClipOval(
                              child: Image.file(
                                File(selectedImage!.path),
                                fit: BoxFit.cover,
                                width: 110,
                                height: 110,
                              ),
                            )
                          : const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.camera_alt_rounded, color: AppColors.primary, size: 32),
                                SizedBox(height: 4),
                                Text(
                                  "Take Photo",
                                  style: TextStyle(color: AppColors.textSecondary, fontSize: 10),
                                ),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Gallery option button
                  TextButton.icon(
                    onPressed: () async {
                      final picked = await _picker.pickImage(
                        source: ImageSource.gallery,
                        imageQuality: 85,
                      );
                      if (picked != null) {
                        setDialogState(() => selectedImage = picked);
                      }
                    },
                    icon: const Icon(Icons.photo_library_outlined, size: 16, color: AppColors.primary),
                    label: const Text("Choose from Gallery", style: TextStyle(color: AppColors.primary, fontSize: 12)),
                  ),
                  const SizedBox(height: 12),

                  // Name field
                  TextField(
                    controller: nameController,
                    style: const TextStyle(color: AppColors.textPrimary),
                    decoration: InputDecoration(
                      labelText: "Full Name",
                      labelStyle: const TextStyle(color: AppColors.textSecondary),
                      filled: true,
                      fillColor: AppColors.surfaceLight,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Relationship dropdown
                  DropdownButtonFormField<String>(
                    initialValue: relationship,
                    dropdownColor: AppColors.surfaceLight,
                    style: const TextStyle(color: AppColors.textPrimary),
                    decoration: InputDecoration(
                      labelText: "Relationship",
                      labelStyle: const TextStyle(color: AppColors.textSecondary),
                      filled: true,
                      fillColor: AppColors.surfaceLight,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    items: const [
                      DropdownMenuItem(value: "Family", child: Text("Family Member")),
                      DropdownMenuItem(value: "Friend", child: Text("Close Friend")),
                      DropdownMenuItem(value: "Resident", child: Text("Resident")),
                      DropdownMenuItem(value: "Staff", child: Text("Staff / Worker")),
                    ],
                    onChanged: (val) {
                      if (val != null) setDialogState(() => relationship = val);
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("Cancel", style: TextStyle(color: AppColors.textMuted)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                onPressed: (isSubmitting || selectedImage == null)
                    ? null
                    : () async {
                        final name = nameController.text.trim();
                        if (name.isEmpty) return;

                        setDialogState(() => isSubmitting = true);
                        final sec = Provider.of<SecurityProvider>(context, listen: false);
                        final success = await sec.registerNewFace(name, relationship, selectedImage!.path);

                        if (context.mounted) {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                success
                                    ? "Successfully registered $name for Face Recognition!"
                                    : "Failed to register face. Please try again.",
                              ),
                            ),
                          );
                        }
                      },
                child: isSubmitting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2),
                      )
                    : const Text(
                        "Enroll",
                        style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                      ),
              ),
            ],
          );
        },
      ),
    );
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
          "AUTHORIZED FACES",
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddFaceDialog,
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add_a_photo_rounded, color: Colors.black),
        label: const Text(
          "Add Person",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () => sec.refreshFaces(),
        color: AppColors.primary,
        backgroundColor: AppColors.surface,
        child: sec.faces.isEmpty
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.border),
                      ),
                      child: const Icon(Icons.face_unlock_rounded, size: 48, color: AppColors.textMuted),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      "No Authorized Faces Registered",
                      style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      "Tap 'Add Person' to enroll your face for auto-unlock.",
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                    ),
                  ],
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: sec.faces.length,
                itemBuilder: (context, index) {
                  final person = sec.faces[index];
                  final photoUrl = person.photoFilename != null
                      ? "${sec.baseUrl}/static/known_faces/${person.photoFilename}"
                      : null;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        // Avatar
                        CircleAvatar(
                          radius: 26,
                          backgroundColor: AppColors.surfaceLight,
                          backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
                          child: photoUrl == null
                              ? const Icon(Icons.person, color: AppColors.primary)
                              : null,
                        ),
                        const SizedBox(width: 14),

                        // Info
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                person.name,
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.safeGreen.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  person.relationship.toUpperCase(),
                                  style: const TextStyle(
                                    color: AppColors.safeGreen,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Delete button
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, color: AppColors.alertRed),
                          onPressed: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                backgroundColor: AppColors.surface,
                                title: const Text("Delete Person?", style: TextStyle(color: AppColors.textPrimary)),
                                content: Text("Remove ${person.name} from authorized access?"),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx, false),
                                    child: const Text("Cancel"),
                                  ),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.alertRed),
                                    onPressed: () => Navigator.pop(ctx, true),
                                    child: const Text("Delete"),
                                  ),
                                ],
                              ),
                            );

                            if (confirm == true) {
                              await sec.deleteFace(person.id);
                            }
                          },
                        ),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }
}
