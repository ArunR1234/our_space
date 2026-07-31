import 'dart:async';
import 'package:flutter/material.dart';

// ─────────────────── PIN LOCK SCREEN ───────────────────
class PinLockScreen extends StatefulWidget {
  final String correctPin;
  final Widget destination;
  const PinLockScreen({super.key, required this.correctPin, required this.destination});

  @override
  State<PinLockScreen> createState() => _PinLockScreenState();
}

class _PinLockScreenState extends State<PinLockScreen> with SingleTickerProviderStateMixin {
  final List<TextEditingController> _controllers = List.generate(4, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(4, (_) => FocusNode());
  bool _hasError = false;
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _shakeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.elasticIn),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_focusNodes.isNotEmpty) _focusNodes[0].requestFocus();
    });
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    _shakeController.dispose();
    super.dispose();
  }

  void _onDigitEntered(String val, int index) {
    if (val.length == 1 && index < 3) {
      _focusNodes[index + 1].requestFocus();
    }
    // Auto-check when 4th digit entered
    if (index == 3 && val.isNotEmpty) {
      final entered = _controllers.map((c) => c.text).join();
      if (entered.length == 4) _checkPin(entered);
    }
  }

  void _checkPin(String entered) {
    if (entered == widget.correctPin) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => widget.destination),
      );
    } else {
      _shakeController.forward(from: 0);
      setState(() => _hasError = true);
      for (final c in _controllers) {
        c.clear();
      }
      _focusNodes[0].requestFocus();
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) setState(() => _hasError = false);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Lock Icon
                Container(
                  width: 80, height: 80,
                  decoration: BoxDecoration(
                    color: primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.lock_rounded, size: 40, color: primary),
                ),
                const SizedBox(height: 24),
                Text(
                  'Our Space',
                  style: TextStyle(fontFamily: 'Georgia', fontSize: 28, fontWeight: FontWeight.bold, color: primary),
                ),
                const SizedBox(height: 8),
                Text(
                  'Enter your 4-digit PIN to continue',
                  style: TextStyle(color: const Color(0xFF8E717D), fontSize: 14),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),
                // PIN boxes with shake animation
                AnimatedBuilder(
                  animation: _shakeAnimation,
                  builder: (context, child) {
                    final dx = _shakeController.isAnimating
                        ? 12.0 * (0.5 - _shakeAnimation.value).abs() * (_shakeAnimation.value < 0.5 ? 1 : -1)
                        : 0.0;
                    return Transform.translate(offset: Offset(dx * 4, 0), child: child);
                  },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: List.generate(4, (i) => _buildPinBox(i, primary)),
                  ),
                ),
                const SizedBox(height: 16),
                // Error message
                AnimatedOpacity(
                  opacity: _hasError ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 300),
                  child: Text(
                    '❌ Incorrect PIN. Try again.',
                    style: TextStyle(color: Colors.red.shade400, fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPinBox(int index, Color primary) {
    return Container(
      width: 56, height: 64,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(
          color: _hasError ? Colors.red.shade300 : primary.withValues(alpha: 0.3),
          width: 1.5,
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: primary.withValues(alpha: 0.06), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: TextField(
        controller: _controllers[index],
        focusNode: _focusNodes[index],
        keyboardType: TextInputType.number,
        maxLength: 1,
        obscureText: true,
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: primary),
        decoration: const InputDecoration(counterText: '', border: InputBorder.none),
        onChanged: (val) => _onDigitEntered(val, index),
      ),
    );
  }
}
