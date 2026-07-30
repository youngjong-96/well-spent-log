import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_colors.dart';
import '../../application/providers.dart';

class LockGate extends ConsumerStatefulWidget {
  const LockGate({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<LockGate> createState() => _LockGateState();
}

class _LockGateState extends ConsumerState<LockGate> {
  final _pinController = TextEditingController();
  late Future<bool> _hasPinFuture;
  bool _unlocked = false;
  bool _checking = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _hasPinFuture = ref.read(lockServiceProvider).hasPin();
  }

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _hasPinFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (!snapshot.data! || _unlocked) {
          return widget.child;
        }
        return Scaffold(
          body: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 360),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Icon(
                        Icons.lock_outline,
                        size: 42,
                        color: AppColors.primary,
                      ),
                      const SizedBox(height: 20),
                      Text(
                        '잘쓸결심',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'PIN을 입력해 잠금을 해제하세요.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 28),
                      TextField(
                        controller: _pinController,
                        autofocus: true,
                        obscureText: true,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        maxLength: 8,
                        textAlign: TextAlign.center,
                        onSubmitted: (_) => _unlock(),
                        decoration: InputDecoration(
                          labelText: 'PIN',
                          errorText: _errorText,
                        ),
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: _checking ? null : _unlock,
                        icon: _checking
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.lock_open),
                        label: const Text('잠금 해제'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _unlock() async {
    if (_pinController.text.isEmpty) {
      return;
    }
    setState(() {
      _checking = true;
      _errorText = null;
    });
    final valid = await ref
        .read(lockServiceProvider)
        .verifyPin(_pinController.text);
    if (!mounted) {
      return;
    }
    setState(() {
      _checking = false;
      _unlocked = valid;
      _errorText = valid ? null : 'PIN이 맞지 않습니다.';
    });
  }
}
