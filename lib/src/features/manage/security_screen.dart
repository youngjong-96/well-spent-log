import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers.dart';

class SecurityScreen extends ConsumerStatefulWidget {
  const SecurityScreen({super.key});

  @override
  ConsumerState<SecurityScreen> createState() => _SecurityScreenState();
}

class _SecurityScreenState extends ConsumerState<SecurityScreen> {
  late Future<bool> _hasPinFuture;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _hasPinFuture = ref.read(lockServiceProvider).hasPin();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('앱 잠금')),
      body: FutureBuilder<bool>(
        future: _hasPinFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done || _saving) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: TextButton(
                onPressed: () => setState(_reload),
                child: const Text('PIN 확인 다시 시도'),
              ),
            );
          }
          final enabled = snapshot.data!;
          return ListView(
            children: [
              ListTile(
                minTileHeight: 68,
                leading: Icon(enabled ? Icons.lock : Icons.lock_open),
                title: Text(enabled ? 'PIN 잠금 사용 중' : 'PIN 잠금 꺼짐'),
                subtitle: const Text('앱을 시작할 때 숫자 PIN을 확인합니다.'),
              ),
              const Divider(height: 24),
              ListTile(
                leading: const Icon(Icons.pin_outlined),
                title: Text(enabled ? 'PIN 변경' : 'PIN 설정'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _setPin(enabled),
              ),
              if (enabled)
                ListTile(
                  leading: const Icon(Icons.lock_open_outlined),
                  title: const Text('잠금 해제'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _removePin,
                ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _setPin(bool enabled) async {
    if (enabled && !await _confirmCurrentPin('PIN을 변경할까요?', '계속')) {
      return;
    }
    if (!mounted) return;
    var pin = '';
    var confirmation = '';
    String? errorText;
    final result = await showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('PIN 설정'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                autofocus: true,
                obscureText: true,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                maxLength: 8,
                onChanged: (value) => pin = value,
                decoration: InputDecoration(
                  labelText: '숫자 4~8자리',
                  errorText: errorText,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                obscureText: true,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                maxLength: 8,
                onChanged: (value) => confirmation = value,
                decoration: const InputDecoration(labelText: 'PIN 확인'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: () {
                if (pin.length < 4 || pin != confirmation) {
                  setDialogState(() {
                    errorText = pin.length < 4
                        ? '4자리 이상 입력해 주세요.'
                        : 'PIN이 서로 다릅니다.';
                  });
                  return;
                }
                Navigator.pop(context, pin);
              },
              child: const Text('저장'),
            ),
          ],
        ),
      ),
    );
    if (result == null || !mounted) return;
    await _savePin(() => ref.read(lockServiceProvider).setPin(result));
  }

  Future<void> _removePin() async {
    if (!await _confirmCurrentPin('잠금을 해제할까요?', '잠금 해제') || !mounted) {
      return;
    }
    await _savePin(() => ref.read(lockServiceProvider).removePin());
  }

  Future<void> _savePin(Future<void> Function() save) async {
    setState(() => _saving = true);
    try {
      await save();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('PIN 설정을 저장하지 못했어요.')));
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
          _reload();
        });
      }
    }
  }

  Future<bool> _confirmCurrentPin(String title, String action) async {
    var pin = '';
    var checking = false;
    String? errorText;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(title),
          content: TextField(
            autofocus: true,
            obscureText: true,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: (value) => pin = value,
            decoration: InputDecoration(
              labelText: '현재 PIN',
              errorText: errorText,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: checking
                  ? null
                  : () async {
                      setDialogState(() => checking = true);
                      try {
                        final valid = await ref
                            .read(lockServiceProvider)
                            .verifyPin(pin);
                        if (!context.mounted) return;
                        if (valid) {
                          Navigator.pop(context, true);
                          return;
                        }
                        errorText = 'PIN이 맞지 않습니다.';
                      } catch (_) {
                        errorText = 'PIN을 확인하지 못했어요. 다시 시도해 주세요.';
                      }
                      if (context.mounted) {
                        setDialogState(() => checking = false);
                      }
                    },
              child: Text(action),
            ),
          ],
        ),
      ),
    );
    return confirmed == true;
  }
}
