import 'package:flutter/material.dart';

/// 打字机效果文本。点击可立即显示全文。
class TypewriterText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final Duration tick;
  final VoidCallback? onCompleted;

  const TypewriterText({
    super.key,
    required this.text,
    this.style,
    this.tick = const Duration(milliseconds: 16),
    this.onCompleted,
  });

  @override
  State<TypewriterText> createState() => _TypewriterTextState();
}

class _TypewriterTextState extends State<TypewriterText> {
  int _visible = 0;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _restart();
  }

  @override
  void didUpdateWidget(covariant TypewriterText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _restart();
    }
  }

  void _restart() {
    _visible = 0;
    _done = false;
    if (widget.text.isEmpty) {
      _done = true;
      return;
    }
    _scheduleNext();
  }

  void _scheduleNext() {
    Future.delayed(widget.tick, () {
      if (!mounted || _done) return;
      // 让 2500 字左右在 8-12 秒内显示完。
      final step = (widget.text.length / 700).ceil().clamp(1, 40);
      setState(() {
        _visible = (_visible + step).clamp(0, widget.text.length);
        if (_visible >= widget.text.length) {
          _done = true;
        }
      });
      if (!_done) {
        _scheduleNext();
      } else {
        widget.onCompleted?.call();
      }
    });
  }

  void _completeNow() {
    if (_done) return;
    setState(() {
      _visible = widget.text.length;
      _done = true;
    });
    widget.onCompleted?.call();
  }

  @override
  Widget build(BuildContext context) {
    final text = widget.text.length <= _visible
        ? widget.text
        : widget.text.substring(0, _visible);
    return GestureDetector(
      onTap: _completeNow,
      behavior: HitTestBehavior.opaque,
      child: Text(text, style: widget.style),
    );
  }
}