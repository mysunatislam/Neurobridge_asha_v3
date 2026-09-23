// NeuroBridge Asha VitalSense AI — Flutter production widget (mobile/tablet).
// Drop into mobile/lib/vitalsense_monitor.dart. Pairs with the edge TFLite
// pipeline over MethodChannel 'neurobridge/vital' (see EDGE_DEPLOYMENT.md).
// Design: dark clinical theme, ECG waveform, confidence ring, alert banner.

import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class VitalReading {
  final double bpm, resp, confidence;
  final String status, quality, motion, stress;
  final String? alert;
  VitalReading({required this.bpm, required this.resp, required this.confidence,
    required this.status, required this.quality, required this.motion,
    required this.stress, this.alert});
}

class VitalSenseMonitor extends StatefulWidget {
  final String patientId;
  const VitalSenseMonitor({super.key, required this.patientId});
  @override
  State<VitalSenseMonitor> createState() => _VitalSenseMonitorState();
}

class _VitalSenseMonitorState extends State<VitalSenseMonitor> {
  static const _ch = MethodChannel('neurobridge/vital');
  VitalReading _r = VitalReading(bpm: 0, resp: 0, confidence: 0,
      status: 'Calibrating…', quality: '—', motion: 'low', stress: 'Unknown');
  List<double> _wave = [];
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _ch.invokeMethod('start', {'patientId': widget.patientId});
    _t = Timer.periodic(const Duration(seconds: 1), (_) => _poll());
  }

  Future<void> _poll() async {
    try {
      final m = await _ch.invokeMapMethod<String, dynamic>('reading');
      if (m == null) return;
      setState(() {
        _r = VitalReading(
          bpm: (m['bpm'] as num).toDouble(),
          resp: (m['resp'] as num).toDouble(),
          confidence: (m['confidence'] as num).toDouble(),
          status: '${m['status']}', quality: '${m['quality']}',
          motion: '${m['motion']}', stress: '${m['stress']}',
          alert: m['alert'] as String?);
        final w = (m['waveform'] as List?)?.map((e) => (e as num).toDouble()).toList();
        if (w != null) _wave = w;
      });
    } on PlatformException { /* stay on last reading; offline-first */ }
  }

  @override
  void dispose() { _t?.cancel(); _ch.invokeMethod('stop'); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final alert = _r.alert;
    return Scaffold(
      backgroundColor: const Color(0xFF060B18),
      appBar: AppBar(backgroundColor: const Color(0xFF060B18),
        title: const Text('Asha Vital Monitor', style: TextStyle(color: Colors.white)),
        actions: [Chip(label: Text(_r.status,
            style: const TextStyle(fontSize: 11)),
          backgroundColor: _r.confidence >= 75 ? Colors.greenAccent : Colors.amberAccent)],
      ),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        if (alert != null)
          Container(padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.15),
              border: Border.all(color: Colors.redAccent), borderRadius: BorderRadius.circular(12)),
            child: Text(alert, style: const TextStyle(color: Colors.redAccent))),
        const SizedBox(height: 12),
        _HeartCard(reading: _r),
        const SizedBox(height: 12),
        SizedBox(height: 140, child: WaveformView(values: _wave)),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _StatTile('Respiration', '${_r.resp.toStringAsFixed(0)} br/min')),
          const SizedBox(width: 12),
          Expanded(child: _StatTile('Stress', _r.stress)),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _StatTile('Signal', _r.quality)),
          const SizedBox(width: 12),
          Expanded(child: _StatTile('Movement', _r.motion)),
        ]),
      ]),
    );
  }
}

class _HeartCard extends StatelessWidget {
  final VitalReading reading;
  const _HeartCard({required this.reading});
  @override
  Widget build(BuildContext context) {
    return Container(padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(gradient: const LinearGradient(
          colors: [Color(0xFF101B3C), Color(0xFF0B2B4F)]),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.cyanAccent.withOpacity(0.25))),
      child: Row(children: [
        const Text('❤️', style: TextStyle(fontSize: 40)),
        const SizedBox(width: 16),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${reading.bpm.toStringAsFixed(0)} BPM',
            style: const TextStyle(fontSize: 38, fontWeight: FontWeight.bold, color: Colors.white)),
          Text('Confidence ${reading.confidence.toStringAsFixed(0)}% • ${reading.status}',
            style: const TextStyle(color: Colors.cyanAccent)),
        ]),
      ]),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String k, v;
  const _StatTile(this.k, this.v);
  @override
  Widget build(BuildContext context) {
    return Container(padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFF0D1528),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(k, style: const TextStyle(color: Colors.white54, fontSize: 12)),
        const SizedBox(height: 6),
        Text(v, style: const TextStyle(color: Colors.white, fontSize: 18,
          fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

/// Neon ECG-style scrolling waveform.
class WaveformView extends StatelessWidget {
  final List<double> values;
  const WaveformView({super.key, required this.values});
  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _WavePainter(values),
      child: Container(decoration: BoxDecoration(
        color: const Color(0xFF04070F), borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.cyanAccent.withOpacity(0.2)))));
  }
}

class _WavePainter extends CustomPainter {
  final List<double> v;
  _WavePainter(this.v);
  @override
  void paint(Canvas c, Size s) {
    final grid = Paint()..color = Colors.white.withOpacity(0.05)..strokeWidth = 1;
    for (int i = 1; i < 6; i++) {
      c.drawLine(Offset(0, s.height * i / 6), Offset(s.width, s.height * i / 6), grid);
    }
    if (v.isEmpty) return;
    final p = Path();
    for (int i = 0; i < v.length; i++) {
      final x = s.width * i / (v.length - 1);
      final y = s.height / 2 - v[i] * s.height * 0.35;
      i == 0 ? p.moveTo(x, y) : p.lineTo(x, y);
    }
    c.drawPath(p, Paint()..color = const Color(0xFF22FFCC)..strokeWidth = 2.5
      ..style = PaintingStyle.stroke..strokeJoin = StrokeJoin.round);
    // glow
    c.drawPath(p, Paint()..color = const Color(0xFF22FFCC).withOpacity(0.18)
      ..strokeWidth = 8 ..style = PaintingStyle.stroke..maskFilter =
        const MaskFilter.blur(BlurStyle.normal, 6));
  }
  @override
  bool shouldRepaint(_WavePainter o) => o.v != v;
}
