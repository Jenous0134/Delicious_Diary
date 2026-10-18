import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../app/design_system.dart';
import '../../backup/data/backup_service.dart';
import '../../meals/presentation/meal_state.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool busy = false;

  bool get preview => const bool.fromEnvironment('UI_PREVIEW');

  void _previewMessage() => ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('백업과 복원은 Android 앱에서 사용할 수 있습니다.')),
  );

  Future<void> _backup() async {
    if (preview) return _previewMessage();
    setState(() => busy = true);
    try {
      final file = await BackupService().createBackup();
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          text: '한끼일기 백업 파일',
          subject: '한끼일기 ZIP 백업',
        ),
      );
    } catch (error) {
      if (mounted) _showError('백업 파일을 만들지 못했습니다.', error);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _restore() async {
    if (preview) return _previewMessage();
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['zip'],
    );
    final path = result.firstOrNull?.path;
    if (path == null) return;
    setState(() => busy = true);
    try {
      final service = BackupService();
      final summary = await service.inspectBackup(File(path));
      if (!mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('백업을 복원할까요?'),
          content: Text(
            '식사 ${summary.meals}개와 사진 ${summary.photos}개를 복원합니다.\n\n현재 기록은 모두 교체되며, 복원에 실패하면 기존 데이터가 유지됩니다.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('전체 교체'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
      final restored = await service.restoreBackup(File(path));
      ref.read(mealRevisionProvider.notifier).bump();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '식사 ${restored.meals}개와 사진 ${restored.photos}개를 복원했습니다.',
            ),
          ),
        );
      }
    } catch (error) {
      if (mounted) _showError('복원하지 못했습니다. 기존 기록은 유지됩니다.', error);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void _showError(String message, Object error) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$message\n$error')));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('설정')),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        const _BrandHeader(),
        const _SectionLabel('기록 보관'),
        _SettingsTile(
          icon: Icons.backup_outlined,
          title: 'ZIP 백업',
          subtitle: '모든 기록과 원본 사진을 하나의 파일로 내보냅니다.',
          onTap: busy ? null : _backup,
        ),
        _SettingsTile(
          icon: Icons.restore_rounded,
          title: 'ZIP에서 복원',
          subtitle: '백업을 검증한 다음 현재 기록을 안전하게 교체합니다.',
          onTap: busy ? null : _restore,
        ),
        const SizedBox(height: 26),
        const _SectionLabel('앱 정보'),
        const _SettingsTile(
          icon: Icons.storage_outlined,
          title: '로컬 저장',
          subtitle: '사진과 기록은 서버 전송 없이 이 기기에만 보관됩니다.',
        ),
        const _SettingsTile(
          icon: Icons.map_outlined,
          title: '지도와 장소 검색',
          subtitle: '카카오 장소 검색과 OpenStreetMap 지도 화면을 사용합니다.',
        ),
        const _SettingsTile(
          icon: Icons.info_outline_rounded,
          title: '한끼일기 1.0.0',
          subtitle: '내가 먹었던 순간을 다시 보는 개인 음식 사진 아카이브',
        ),
        if (busy) ...[
          const SizedBox(height: 24),
          const LinearProgressIndicator(),
        ],
      ],
    ),
  );
}

class _BrandHeader extends StatelessWidget {
  const _BrandHeader();
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 20),
    child: Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Image.asset('assets/branding/logo.png', width: 64, height: 64),
        ),
        const SizedBox(width: 16),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '한끼일기',
                style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
              ),
              SizedBox(height: 4),
              Text(
                '사진으로 다시 보는 나의 한 끼',
                style: TextStyle(color: AppColors.muted),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      text,
      style: const TextStyle(
        color: AppColors.muted,
        fontSize: 12,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      ListTile(
        contentPadding: const EdgeInsets.symmetric(vertical: 4),
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: const Color(0xFFFFEEE7),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: AppColors.orange, size: 22),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(subtitle),
        trailing: onTap == null
            ? null
            : const Icon(Icons.chevron_right_rounded),
        onTap: onTap,
      ),
      const Divider(),
    ],
  );
}
