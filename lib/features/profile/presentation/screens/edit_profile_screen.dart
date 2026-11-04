
import 'package:flutter/material.dart';

import '../../../auth/data/auth_repository.dart';
import '../../../auth/models/auth_user.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({
    super.key,
    required this.user,
    required this.authRepository,
  });

  final AuthUser user;
  final AuthRepository authRepository;

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _usernameController;
  late final TextEditingController _displayNameController;
  late final TextEditingController _bioController;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();

    _usernameController = TextEditingController(
      text: widget.user.username,
    );
    _displayNameController = TextEditingController(
      text: widget.user.displayName,
    );
    _bioController = TextEditingController(
      text: widget.user.bio ?? '',
    );
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _displayNameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  String? _validateUsername(String? value) {
    final username = value?.trim() ?? '';

    if (!RegExp(r'^[A-Za-z0-9_]{3,30}$').hasMatch(username)) {
      return 'نام کاربری باید ۳ تا ۳۰ کاراکتر انگلیسی، عدد یا زیرخط باشد.';
    }

    return null;
  }

  String? _validateDisplayName(String? value) {
    final displayName = value?.trim() ?? '';

    if (displayName.isEmpty) {
      return 'نام نمایشی را وارد کن.';
    }

    if (displayName.length > 100) {
      return 'نام نمایشی نباید بیشتر از ۱۰۰ کاراکتر باشد.';
    }

    return null;
  }

  String? _validateBio(String? value) {
    if ((value ?? '').length > 500) {
      return 'توضیحات نباید بیشتر از ۵۰۰ کاراکتر باشد.';
    }

    return null;
  }

  Future<void> _saveProfile() async {
    if (_isSaving || !_formKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();
    setState(() => _isSaving = true);

    try {
      final username = _usernameController.text.trim();
      final displayName = _displayNameController.text.trim();
      final bioText = _bioController.text.trim();

      final updatedUser = await widget.authRepository.updateProfile(
        username: username,
        displayName: displayName,
        bio: bioText.isEmpty ? null : bioText,
        updateBio: true,
      );

      if (!mounted) return;

      Navigator.of(context).pop(updatedUser);
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('ذخیره تغییرات انجام نشد: $error'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ویرایش پروفایل'),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const Center(
                child: CircleAvatar(
                  radius: 42,
                  child: Icon(Icons.person_outline, size: 44),
                ),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _displayNameController,
                decoration: const InputDecoration(
                  labelText: 'نام نمایشی',
                  hintText: 'نامی که دیگران می‌بینند',
                  prefixIcon: Icon(Icons.person_outline),
                  border: OutlineInputBorder(),
                ),
                textInputAction: TextInputAction.next,
                maxLength: 100,
                validator: _validateDisplayName,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _usernameController,
                decoration: const InputDecoration(
                  labelText: 'نام کاربری',
                  prefixIcon: Icon(Icons.alternate_email),
                  border: OutlineInputBorder(),
                ),
                textInputAction: TextInputAction.next,
                autocorrect: false,
                validator: _validateUsername,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _bioController,
                decoration: const InputDecoration(
                  labelText: 'درباره من',
                  hintText: 'چند جمله درباره خودت بنویس...',
                  prefixIcon: Icon(Icons.notes_outlined),
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                minLines: 3,
                maxLines: 5,
                maxLength: 500,
                validator: _validateBio,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _isSaving ? null : _saveProfile,
                icon: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.save_outlined),
                label: Text(
                  _isSaving ? 'در حال ذخیره...' : 'ذخیره تغییرات',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
