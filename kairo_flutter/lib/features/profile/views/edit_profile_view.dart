import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/models/kairo_user.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/theme/kairo_colors.dart';
import '../../../core/utils/username.dart';
import '../../../core/widgets/kairo_avatar.dart';
import '../../auth/services/auth_service.dart';
import '../../users/services/users_repository.dart';
import 'avatar_crop_view.dart';

class EditProfileView extends StatefulWidget {
  const EditProfileView({super.key});

  @override
  State<EditProfileView> createState() => _EditProfileViewState();
}

class _EditProfileViewState extends State<EditProfileView> {
  final _users = UsersRepository();
  final _name = TextEditingController();
  final _username = TextEditingController();
  final _bio = TextEditingController();

  KairoUser? _user;
  bool _loading = true;
  bool _saving = false;
  bool _changingPhoto = false;
  String? _error;

  bool get _canChangeUsername => UsernamePolicy.canChange(_user?.usernameChangedAt);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _name.dispose();
    _username.dispose();
    _bio.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      var user = await _users.getCurrentUser();
      if (user != null) {
        user = await _users.ensureGeneratedUsername(user);
      }
      if (!mounted) return;
      _user = user;
      _name.text = _cleanName(user?.name ?? user?.displayName ?? '');
      _username.text = user?.username ?? '';
      _bio.text = user?.bio ?? '';
      setState(() => _loading = false);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'No se pudo cargar tu perfil';
      });
    }
  }

  String _cleanName(String raw) {
    return raw.replaceAll(RegExp(r'[★☆⭐✨*]'), '').replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  Future<ImageSource?> _chooseSource() async {
    if (kIsWeb) return ImageSource.gallery;
    return showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: KairoColors.darkCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 12, 8, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Foto de perfil',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16),
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library_outlined, color: Colors.white),
                  title: const Text('Galería', style: TextStyle(color: Colors.white)),
                  onTap: () => Navigator.pop(ctx, ImageSource.gallery),
                ),
                ListTile(
                  leading: const Icon(Icons.photo_camera_outlined, color: Colors.white),
                  title: const Text('Cámara', style: TextStyle(color: Colors.white)),
                  onTap: () => Navigator.pop(ctx, ImageSource.camera),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _changePhoto() async {
    if (_changingPhoto) return;
    final source = await _chooseSource();
    if (source == null || !mounted) return;
    final file = await ImagePicker().pickImage(source: source, imageQuality: 95);
    if (file == null || !mounted) return;
    final original = await file.readAsBytes();
    if (!mounted) return;
    final cropped = await showAvatarCropper(context, original);
    if (cropped == null || cropped.isEmpty || !mounted) return;
    setState(() {
      _changingPhoto = true;
      _error = null;
    });
    try {
      final url = await StorageService().uploadBytes(
        bytes: cropped,
        fileName: 'avatar.png',
        mimeType: 'image/png',
        subfolder: 'avatars',
      );
      await _users.updateProfile(image: url);
      if (!mounted) return;
      setState(() {
        _user = _user?.copyWith(image: url);
        _changingPhoto = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Foto de perfil actualizada')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _changingPhoto = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _save() async {
    if (_saving || _user == null) return;
    final name = _cleanName(_name.text);
    final username = UsernamePolicy.sanitize(_username.text);
    final bio = _bio.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Escribe tu nombre');
      return;
    }
    final usernameError = UsernamePolicy.validate(username);
    if (usernameError != null) {
      setState(() => _error = usernameError);
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await _users.updateProfile(
        name: name,
        bio: bio,
        username: username,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Perfil actualizado')),
      );
      context.pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  InputDecoration _decoration(String hint, {String? prefix, String? helper}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: KairoColors.darkTextSecondary),
      helperText: helper,
      helperMaxLines: 3,
      helperStyle: const TextStyle(color: KairoColors.darkTextSecondary, fontSize: 12, height: 1.35),
      prefixText: prefix,
      prefixStyle: const TextStyle(color: KairoColors.darkTextSecondary, fontSize: 16),
      filled: true,
      fillColor: KairoColors.darkCard,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!AuthService().isSignedIn) {
      return const Scaffold(
        backgroundColor: KairoColors.darkBg,
        body: Center(child: Text('Inicia sesión para editar tu perfil', style: TextStyle(color: Colors.white))),
      );
    }

    final user = _user;
    final locked = !_canChangeUsername && user?.usernameChangedAt != null;

    return Scaffold(
      backgroundColor: KairoColors.darkBg,
      appBar: AppBar(
        backgroundColor: KairoColors.darkBg,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text('Editar perfil', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: KairoColors.primary500))
          : user == null
              ? Center(
                  child: Text(_error ?? 'No se encontró tu perfil', style: const TextStyle(color: KairoColors.darkTextSecondary)),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                  children: [
                    Center(
                      child: GestureDetector(
                        onTap: _changingPhoto || _saving ? null : _changePhoto,
                        child: Column(
                          children: [
                            Stack(
                              alignment: Alignment.center,
                              children: [
                                KairoAvatar(imageUrl: user.image, name: namePreview(user), size: 104),
                                if (_changingPhoto)
                                  const SizedBox(
                                    width: 28,
                                    height: 28,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: KairoColors.primary400),
                                  ),
                                if (!_changingPhoto)
                                  Positioned(
                                    right: 2,
                                    bottom: 2,
                                    child: Container(
                                      width: 32,
                                      height: 32,
                                      decoration: BoxDecoration(
                                        color: KairoColors.primary500,
                                        shape: BoxShape.circle,
                                        border: Border.all(color: KairoColors.darkBg, width: 2),
                                      ),
                                      child: const Icon(Icons.photo_camera_outlined, color: Colors.white, size: 16),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            const Text(
                              'Cambiar foto de perfil',
                              style: TextStyle(color: KairoColors.primary400, fontWeight: FontWeight.w600, fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    const Text('Nombre', style: TextStyle(color: KairoColors.darkTextSecondary, fontSize: 12)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _name,
                      style: const TextStyle(color: Colors.white),
                      textCapitalization: TextCapitalization.words,
                      decoration: _decoration('Tu nombre'),
                    ),
                    const SizedBox(height: 18),
                    const Text('Usuario', style: TextStyle(color: KairoColors.darkTextSecondary, fontSize: 12)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _username,
                      enabled: _canChangeUsername && !_saving,
                      style: TextStyle(color: _canChangeUsername ? Colors.white : KairoColors.darkTextSecondary),
                      maxLength: UsernamePolicy.maxLength,
                      decoration: _decoration(
                        'usuario',
                        prefix: '@',
                        helper: locked
                            ? UsernamePolicy.cooldownMessage(user.usernameChangedAt!)
                            : 'Único. Solo se puede cambiar una vez cada 6 meses.',
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text('Descripción', style: TextStyle(color: KairoColors.darkTextSecondary, fontSize: 12)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _bio,
                      maxLines: 3,
                      maxLength: 150,
                      style: const TextStyle(color: Colors.white),
                      decoration: _decoration('Cuéntale a la comunidad quién eres'),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 8),
                      Text(_error!, style: const TextStyle(color: KairoColors.errorText, fontSize: 13)),
                    ],
                    const SizedBox(height: 20),
                    SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _saving ? null : _save,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: KairoColors.primary500,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: KairoColors.primary500.withValues(alpha: 0.5),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: _saving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Text('Guardar', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                      ),
                    ),
                  ],
                ),
    );
  }

  String namePreview(KairoUser user) {
    final typed = _cleanName(_name.text);
    if (typed.isNotEmpty) return typed;
    return user.displayName;
  }
}
