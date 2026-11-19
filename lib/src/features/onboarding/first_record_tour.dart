import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'onboarding_style.dart';

class FirstRecordTour extends StatelessWidget {
  const FirstRecordTour({required this.step, required this.onNext, super.key});

  final int step;
  final VoidCallback onNext;

  static const _copy = [
    ('사용한 금액을 입력해요', '사용한 금액을 원 단위로 입력해요. 예시는 15,000원이에요.'),
    ('어디에 썼는지 메모해요', '메모를 남기면 내역에서 어떤 지출이었는지 쉽게 기억할 수 있어요.'),
    ('기록 정보를 한눈에 확인해요', '분류, 결제수단, 날짜가 이 줄에 보여요. 누르면 상세 설정이 열려요.'),
    ('필요하면 상세 정보를 바꿔요', '카테고리, 결제수단, 사용한 날짜를 바꿀 수 있어요.'),
    ('확인했다면 저장해요', '저장하면 내역에 기록되고 홈의 남은 예산도 바뀌어요.'),
  ];

  Widget _dim(Widget child) => ColorFiltered(
    colorFilter: const ColorFilter.mode(onboardingTourShade, BlendMode.srcATop),
    child: child,
  );

  Widget _target(int index, LayerLink link, Widget child) => index == step
      ? CompositedTransformTarget(
          link: link,
          child: DecoratedBox(
            position: DecorationPosition.foreground,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(13),
              border: Border.all(
                color: onboardingAccent,
                width: 2,
                strokeAlign: BorderSide.strokeAlignOutside,
              ),
            ),
            child: child,
          ),
        )
      : _dim(child);

  Widget _note({bool above = false}) => Stack(
    clipBehavior: Clip.none,
    children: [
      Positioned(
        left: above ? null : 34,
        right: above ? 59 : null,
        top: above ? null : -6,
        bottom: above ? -6 : null,
        child: Transform.rotate(
          angle: math.pi / 4,
          child: Container(
            width: 13,
            height: 13,
            decoration: BoxDecoration(
              color: onboardingLine,
              border: Border(
                top: above
                    ? BorderSide.none
                    : const BorderSide(color: onboardingAccent),
                left: above
                    ? BorderSide.none
                    : const BorderSide(color: onboardingAccent),
                bottom: above
                    ? const BorderSide(color: onboardingAccent)
                    : BorderSide.none,
                right: above
                    ? const BorderSide(color: onboardingAccent)
                    : BorderSide.none,
              ),
            ),
          ),
        ),
      ),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 11),
        decoration: onboardingBox(
          color: onboardingLine,
          border: onboardingAccent,
          radius: 16,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_copy[step - 1].$1, style: onboardingType(20, bold: true)),
            const SizedBox(height: 5),
            Text(_copy[step - 1].$2, style: onboardingType(17, height: 1.45)),
          ],
        ),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final expanded = step >= 4;
    final link = LayerLink();
    final today = DateTime.now();
    return PopScope(
      canPop: false,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final scale = MediaQuery.textScalerOf(context).scale(17) / 17;
          final height = math.max(
            constraints.maxHeight,
            750.0 +
                (360 - constraints.maxWidth).clamp(0, 65) * 1.6 +
                (scale - 1).clamp(0.0, 2.0).toDouble() * 680,
          );
          return FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: constraints.maxWidth,
              height: height,
              child: ColoredBox(
                color: onboardingTourBackground,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ExcludeSemantics(child: _dim(firstRecordHeader())),
                          Expanded(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: Color.alphaBlend(
                                  onboardingTourShade,
                                  onboardingSurface,
                                ),
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(24),
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  20,
                                  12,
                                  20,
                                  0,
                                ),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Expanded(
                                      child: ExcludeSemantics(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.stretch,
                                          children: [
                                            _dim(firstRecordSheetTitle()),
                                            for (final item in [
                                              (
                                                1,
                                                firstRecordField(
                                                  '금액',
                                                  Text(
                                                    '15,000',
                                                    style: onboardingType(
                                                      34,
                                                      bold: true,
                                                    ),
                                                  ),
                                                  trailing: const Text('원'),
                                                  height: 80,
                                                ),
                                              ),
                                              (
                                                2,
                                                firstRecordField(
                                                  '어떤 지출인가요?',
                                                  Text(
                                                    '점심 김치찌개',
                                                    style: onboardingType(
                                                      20,
                                                      bold: true,
                                                    ),
                                                  ),
                                                  trailing: const Icon(
                                                    Icons.edit,
                                                    size: 20,
                                                  ),
                                                  height: 72,
                                                ),
                                              ),
                                              (
                                                3,
                                                firstRecordSummary(
                                                  '식비 · 국민카드 · 오늘',
                                                  expanded,
                                                ),
                                              ),
                                              if (expanded)
                                                (
                                                  4,
                                                  Column(
                                                    key: const ValueKey(
                                                      'tour-details',
                                                    ),
                                                    children: [
                                                      firstRecordType(false),
                                                      const SizedBox(height: 6),
                                                      firstRecordDetail(
                                                        '카테고리',
                                                        '식비',
                                                        Icons.expand_more,
                                                      ),
                                                      const SizedBox(height: 6),
                                                      firstRecordDetail(
                                                        '결제수단',
                                                        '국민카드',
                                                        Icons.expand_more,
                                                      ),
                                                      const SizedBox(height: 6),
                                                      firstRecordDetail(
                                                        '날짜',
                                                        '오늘 · ${today.month}월 ${today.day}일',
                                                        Icons.chevron_right,
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                            ]) ...[
                                              const SizedBox(height: 11),
                                              _target(item.$1, link, item.$2),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ),
                                    ExcludeSemantics(
                                      child: ExcludeFocus(
                                        child: Row(
                                          children: [
                                            Expanded(
                                              flex: 128,
                                              child: _dim(
                                                IgnorePointer(
                                                  child: onboardingButton(
                                                    expanded
                                                        ? '분류·결제 접기'
                                                        : '분류·결제 확인',
                                                    () {},
                                                    secondary: true,
                                                    icon: expanded
                                                        ? Icons.expand_less
                                                        : Icons.expand_more,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              flex: 100,
                                              child: _target(
                                                5,
                                                link,
                                                IgnorePointer(
                                                  child: onboardingButton(
                                                    '저장',
                                                    () {},
                                                    icon: Icons.check,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Container(
                                      decoration: onboardingBox(
                                        border: onboardingLine,
                                        radius: 16,
                                      ),
                                      padding: const EdgeInsets.fromLTRB(
                                        15,
                                        9,
                                        10,
                                        9,
                                      ),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  '기록 화면 둘러보기',
                                                  style: onboardingType(
                                                    16,
                                                    color: onboardingAccent,
                                                  ),
                                                ),
                                                Text(
                                                  '$step/5',
                                                  style: onboardingType(
                                                    20,
                                                    bold: true,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          SizedBox(
                                            width: 110,
                                            child: onboardingButton(
                                              '다음',
                                              onNext,
                                              compact: true,
                                              labelSize: 19,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      top: 0,
                      left: 20,
                      width: constraints.maxWidth - 40,
                      child: IgnorePointer(
                        child: CompositedTransformFollower(
                          link: link,
                          targetAnchor: step == 5
                              ? Alignment.topRight
                              : Alignment.bottomLeft,
                          followerAnchor: step == 5
                              ? Alignment.bottomRight
                              : Alignment.topLeft,
                          offset: Offset(0, step == 5 ? -20 : 10),
                          child: _note(above: step == 5),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

Widget firstRecordHeader({bool live = false}) => Padding(
  padding: const EdgeInsets.fromLTRB(20, 8, 20, 6),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          Expanded(child: Text('첫 기록', style: onboardingType(26, bold: true))),
          Text(
            '4/4',
            style: onboardingType(16, color: onboardingAccent, bold: true),
          ),
        ],
      ),
      const SizedBox(height: 10),
      onboardingMeter(1),
      if (live) ...[
        const SizedBox(height: 12),
        onboardingInfo(
          '사용한 금액을 자유롭게 기록해 보세요.',
          icon: Icons.edit,
          shaded: true,
          compact: true,
        ),
      ],
    ],
  ),
);

Widget firstRecordSheetTitle({VoidCallback? onClose}) => Column(
  children: [
    Container(
      width: 36,
      height: 4,
      decoration: onboardingBox(color: onboardingMuted),
    ),
    const SizedBox(height: 9),
    Row(
      children: [
        Expanded(child: Text('지출 추가', style: onboardingType(26, bold: true))),
        if (onClose == null)
          const Icon(Icons.close, size: 22, color: onboardingMuted)
        else
          IconButton(
            tooltip: '닫기',
            visualDensity: VisualDensity.compact,
            onPressed: onClose,
            icon: const Icon(Icons.close, color: onboardingMuted),
          ),
      ],
    ),
  ],
);

Widget firstRecordField(
  String label,
  Widget value, {
  required Widget trailing,
  required double height,
}) => Container(
  constraints: BoxConstraints(minHeight: height),
  decoration: onboardingBox(
    color: onboardingBackground,
    border: onboardingLine,
  ),
  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
  child: Row(
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: onboardingType(15, color: onboardingMuted)),
            value,
          ],
        ),
      ),
      const SizedBox(width: 8),
      trailing,
    ],
  ),
);

Widget firstRecordSummary(String value, bool expanded, {VoidCallback? onTap}) =>
    Material(
      color: onboardingRaised,
      borderRadius: BorderRadius.circular(13),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(13),
        child: Container(
          constraints: const BoxConstraints(minHeight: 49),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  value,
                  style: onboardingType(17),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(
                expanded ? Icons.expand_less : Icons.chevron_right,
                color: onboardingAccent,
              ),
            ],
          ),
        ),
      ),
    );

Widget firstRecordType(bool refund, {ValueChanged<bool>? onChanged}) =>
    Container(
      clipBehavior: Clip.antiAlias,
      decoration: onboardingBox(border: onboardingLine, radius: 12),
      child: Row(
        children: [
          for (final item in [(false, '일반 지출'), (true, '환불/취소')])
            Expanded(
              child: Material(
                color: refund == item.$1 ? onboardingLine : onboardingSurface,
                child: InkWell(
                  onTap: onChanged == null ? null : () => onChanged(item.$1),
                  child: Container(
                    alignment: Alignment.center,
                    constraints: const BoxConstraints(minHeight: 36),
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(item.$2, style: onboardingType(16)),
                  ),
                ),
              ),
            ),
        ],
      ),
    );

Widget firstRecordDetail(
  String label,
  String value,
  IconData icon, {
  VoidCallback? onTap,
}) => Material(
  color: onboardingBackground,
  shape: RoundedRectangleBorder(
    side: const BorderSide(color: onboardingLine),
    borderRadius: BorderRadius.circular(13),
  ),
  child: InkWell(
    borderRadius: BorderRadius.circular(13),
    onTap: onTap,
    child: Container(
      constraints: const BoxConstraints(minHeight: 38),
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 4),
      child: Row(
        children: [
          Text(label, style: onboardingType(15, color: onboardingMuted)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              style: onboardingType(17, bold: true),
              textAlign: TextAlign.end,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 6),
          Icon(icon, size: 19),
        ],
      ),
    ),
  ),
);
