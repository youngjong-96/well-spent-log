import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../application/providers.dart';

enum _CsvExportFormat { csv, zip }

class BackupScreen extends ConsumerStatefulWidget {
  const BackupScreen({super.key});

  @override
  ConsumerState<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends ConsumerState<BackupScreen> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('백업과 내보내기')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Text(
              '백업 파일에는 지출 금액과 메모가 포함됩니다. '
              '공용 저장소나 다른 사람에게 노출되지 않도록 보관해 주세요.',
            ),
          ),
          const Divider(height: 24),
          FutureBuilder<File?>(
            future: ref.read(backupServiceProvider).findMigrationBackup(),
            builder: (context, snapshot) {
              final file = snapshot.data;
              if (file == null) return const SizedBox.shrink();
              return ListTile(
                leading: const Icon(Icons.history),
                title: const Text('업데이트 전 원본 백업 내보내기'),
                subtitle: const Text('기존 수입·계좌번호·잔액을 포함한 전환 전 기록'),
                enabled: !_busy,
                onTap: () async {
                  if (!await _confirmSensitiveExport()) return;
                  await _run(() => _share(file, '잘쓸결심 업데이트 전 원본 백업'));
                },
              );
            },
          ),
          ListTile(
            minTileHeight: 68,
            leading: const Icon(Icons.backup_outlined),
            title: const Text('전체 백업 내보내기'),
            subtitle: const Text('복원 가능한 JSON 파일'),
            trailing: const Icon(Icons.ios_share),
            enabled: !_busy,
            onTap: _exportJson,
          ),
          ListTile(
            minTileHeight: 68,
            leading: const Icon(Icons.table_view_outlined),
            title: const Text('거래내역 내보내기'),
            subtitle: const Text('CSV 파일 또는 공유용 ZIP 파일'),
            trailing: const Icon(Icons.ios_share),
            enabled: !_busy,
            onTap: _exportCsv,
          ),
          const Divider(height: 24),
          ListTile(
            minTileHeight: 68,
            leading: const Icon(Icons.restore_outlined),
            title: const Text('JSON 백업 가져오기'),
            subtitle: const Text('현재 데이터를 모두 백업 파일로 교체'),
            trailing: const Icon(Icons.chevron_right),
            enabled: !_busy,
            onTap: _importJson,
          ),
          if (_busy)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }

  Future<void> _exportJson() async {
    if (!await _confirmSensitiveExport()) {
      return;
    }
    await _run(() async {
      final file = await ref.read(backupServiceProvider).createJsonBackup();
      await _share(file, '잘쓸결심 전체 백업');
    });
  }

  Future<void> _exportCsv() async {
    if (!await _confirmSensitiveExport()) {
      return;
    }
    if (!mounted) return;
    final format = await showModalBottomSheet<_CsvExportFormat>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.table_view_outlined),
              title: const Text('CSV 파일 공유'),
              subtitle: const Text('엑셀 등에서 바로 열 수 있어요'),
              onTap: () => Navigator.pop(context, _CsvExportFormat.csv),
            ),
            ListTile(
              leading: const Icon(Icons.folder_zip_outlined),
              title: const Text('ZIP으로 공유'),
              subtitle: const Text('카카오톡 등에서 CSV가 전송되지 않을 때 사용하세요'),
              onTap: () => Navigator.pop(context, _CsvExportFormat.zip),
            ),
          ],
        ),
      ),
    );
    if (!mounted || format == null) return;
    await _run(() async {
      final service = ref.read(backupServiceProvider);
      final file = format == _CsvExportFormat.zip
          ? await service.createCsvZipExport()
          : await service.createCsvExport();
      await _share(file, '잘쓸결심 거래내역');
    });
  }

  Future<void> _importJson() async {
    const jsonType = XTypeGroup(label: 'JSON 백업', extensions: ['json']);
    final selected = await openFile(acceptedTypeGroups: [jsonType]);
    if (selected == null || !mounted) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('현재 데이터를 교체할까요?'),
        content: const Text(
          '가져오기를 실행하면 현재 앱의 모든 지출·예산·결제수단 데이터가 '
          '선택한 백업 내용으로 대체됩니다. 이 작업은 되돌릴 수 없습니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('교체하고 복원'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    await _run(() async {
      final bytes = await selected.readAsBytes();
      await ref.read(backupServiceProvider).restoreJson(bytes);
      await ref.read(financeRepositoryProvider).refreshAfterRestore();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('백업을 복원했어요')));
      }
    });
  }

  Future<bool> _confirmSensitiveExport() async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('민감한 정보가 포함됩니다'),
            content: const Text(
              '파일에는 지출 금액과 메모 등 개인 정보가 포함될 수 있습니다. '
              '업데이트 전 원본 백업에는 기존 계좌번호와 잔액도 포함됩니다. '
              '안전한 위치에만 저장해 주세요.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('취소'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('계속'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _share(File file, String subject) async {
    if (!mounted) return;
    final box = context.findRenderObject() as RenderBox?;
    final mimeType = switch (file.uri.pathSegments.last
        .split('.')
        .last
        .toLowerCase()) {
      // Some Android receivers treat text/csv as a text message instead of a
      // document attachment. Preserve .csv and its bytes, but request file sharing.
      'csv' =>
        defaultTargetPlatform == TargetPlatform.android
            ? 'application/octet-stream'
            : 'text/csv',
      'zip' => 'application/zip',
      _ => 'application/json',
    };
    final result = await SharePlus.instance.share(
      ShareParams(
        subject: subject,
        files: [XFile(file.path, mimeType: mimeType)],
        sharePositionOrigin: box == null
            ? null
            : box.localToGlobal(Offset.zero) & box.size,
      ),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            result.status == ShareResultStatus.dismissed
                ? '공유를 취소했어요.'
                : '파일 공유를 요청했어요. 전송 결과는 공유 앱에서 확인해 주세요.',
          ),
        ),
      );
  }

  Future<void> _run(Future<void> Function() operation) async {
    setState(() => _busy = true);
    try {
      await operation();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('작업을 완료하지 못했어요: $error')));
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }
}
