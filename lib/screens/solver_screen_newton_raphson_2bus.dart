// lib/screens/solver_screen_newton_raphson_2bus.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_math_fork/flutter_math.dart';

import '/domain/complex.dart';
import '/domain/powerflow_model_nr2.dart';
import '/domain/powerflow_solver_nr2.dart';
import '/utils/format.dart';
import '/widgets/latex_blocks.dart';
import '/widgets/ui_helpers.dart';

enum DisplayMode { rect, polar, both }

class SolverScreenNR2Bus extends StatefulWidget {
const SolverScreenNR2Bus({super.key});

@override
State<SolverScreenNR2Bus> createState() => _SolverScreenNR2BusState();
}

class _SolverScreenNR2BusState extends State<SolverScreenNR2Bus> {
// INPUTS 
// Base / line data
final _sBaseCtrl = TextEditingController(text: '100'); // MVA
final _vBaseCtrl = TextEditingController(text: '230'); // kV
final _r12Ctrl = TextEditingController(text: '20'); // Ω or pu
final _x12Ctrl = TextEditingController(text: '80'); // Ω or pu
final _ypCtrl = TextEditingController(text: '0.00027'); // S/ph or pu 

// Bus 1 (Slack) voltage
final _v1MagCtrl = TextEditingController(text: '1.0');
final _d1Ctrl = TextEditingController(text: '0');

// Bus 1 power inputs 
final _pg1Ctrl = TextEditingController(text: '0');
final _qg1Ctrl = TextEditingController(text: '0');
final _pd1Ctrl = TextEditingController(text: '0');
final _qd1Ctrl = TextEditingController(text: '0');

// Bus 2 initial PV magnitude specified or flat-start guess
final _v2InitMagCtrl = TextEditingController(text: '1.0');
final _d2InitCtrl = TextEditingController(text: '0');

// Bus 2 power inputs
final _pg2Ctrl = TextEditingController(text: '0');
final _qg2Ctrl = TextEditingController(text: '0');
final _pd2Ctrl = TextEditingController(text: '1.0'); // Sd2 real
final _qd2Ctrl = TextEditingController(text: '1.0'); // Sd2 imag

// PV bus Qg limits (generator-side limits)
final _qg2MinCtrl = TextEditingController(text: ''); // optional
final _qg2MaxCtrl = TextEditingController(text: ''); // optional

// Iteration controls
final _tolCtrl = TextEditingController(text: '1e-4');
final _maxIterCtrl = TextEditingController(text: '50');

// Fixed-iteration (k-times) when convergence is OFF
final _kTimesCtrl = TextEditingController(text: '2');

// Toggles / dropdowns
bool _lineDataInPu = false;
bool _bus1PowerInPu = true;
bool _bus2PowerInPu = true;

BusType _bus1Type = BusType.slack;
BusType _bus2Type = BusType.pq;
Bus1Given _bus1Given = Bus1Given.none;

// Iterate mode
bool _iterateUntilConverge = true;

// PRESETS Quick Fill Dropdown
late final List<NR2Preset> _presets = nr2Presets;
NR2Preset? _selectedPreset;

void _applyPreset(NR2Preset p) {
setState(() {
// toggles / dropdowns
_lineDataInPu = p.lineDataInPu;
_bus1PowerInPu = p.bus1PowerInPu;
_bus2PowerInPu = p.bus2PowerInPu;
_iterateUntilConverge = p.iterateUntilConverge;

// Bus 1 slack 
_bus1Type = BusType.slack;
_bus2Type = p.bus2Type;
_bus1Given = p.bus1Given;

// base/line
_sBaseCtrl.text = p.sBase;
_vBaseCtrl.text = p.vBase;
_r12Ctrl.text = p.r12;
_x12Ctrl.text = p.x12;
_ypCtrl.text = p.yp;

// bus 1
_v1MagCtrl.text = p.v1Mag;
_d1Ctrl.text = p.d1;

_pg1Ctrl.text = p.pg1;
_qg1Ctrl.text = p.qg1;
_pd1Ctrl.text = p.pd1;
_qd1Ctrl.text = p.qd1;

// bus 2
_v2InitMagCtrl.text = p.v2Mag;
_d2InitCtrl.text = p.d2;

_pg2Ctrl.text = p.pg2;
_qg2Ctrl.text = p.qg2;
_pd2Ctrl.text = p.pd2;
_qd2Ctrl.text = p.qd2;

// PV Q-limits
_qg2MinCtrl.text = p.qg2Min;
_qg2MaxCtrl.text = p.qg2Max;

// iteration
_tolCtrl.text = p.tol;
_maxIterCtrl.text = p.maxIter;
_kTimesCtrl.text = p.kTimes;

// reset output
_error = null;
res = null;

// reset workings UI
_showAllWorkings = false;
_openStep = -1;
});
}

// 2-bus diagram helpers
Rect _containRect({
required double containerW,
required double containerH,
required double imageAspect, // width / height
}) {
final containerAspect = containerW / containerH;

double w, h, left, top;

if (containerAspect > imageAspect) {
h = containerH;
w = h * imageAspect;
left = (containerW - w) / 2.0;
top = 0.0;
} else {
w = containerW;
h = w / imageAspect;
left = 0.0;
top = (containerH - h) / 2.0;
}

return Rect.fromLTWH(left, top, w, h);
}

Widget _latexChip(String latex, {double size = 15}) {
return Container(
padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
decoration: BoxDecoration(
color: Colors.white.withOpacity(0.92),
borderRadius: BorderRadius.circular(6),
border: Border.all(color: Colors.black12),
),
child: Math.tex(
latex,
mathStyle: MathStyle.text,
textStyle: TextStyle(fontSize: size, color: Colors.black87),
),
);
}

Widget _diagLabelFrac(
Rect imageRect, {
required double x, 
required double y, 
required String latex,
double size = 15,
}) {
return Positioned(
left: imageRect.left + x * imageRect.width,
top: imageRect.top + y * imageRect.height,
child: _latexChip(latex, size: size),
);
}

// UI state
DisplayMode mode = DisplayMode.both;
String? _error;
NR2Result? res;

// show/close workings states 
bool _showAllWorkings = false;
int _openStep = -1;

// Parsing helpers
double _p(TextEditingController c, double fallback) {
final t = c.text.trim();
if (t.isEmpty) return fallback;
final v = double.tryParse(t) ?? double.tryParse(t.toLowerCase().replaceAll('e', 'E'));
return v ?? fallback;
}

double? _pOpt(TextEditingController c) {
final t = c.text.trim();
if (t.isEmpty) return null;
final v = double.tryParse(t) ?? double.tryParse(t.toLowerCase().replaceAll('e', 'E'));
return v;
}

int _pi(TextEditingController c, int fallback) {
final t = c.text.trim();
return int.tryParse(t) ?? fallback;
}

bool _anyEmpty() {
for (final c in [
_sBaseCtrl,
_vBaseCtrl,
_r12Ctrl,
_x12Ctrl,
_ypCtrl,
_v1MagCtrl,
_d1Ctrl,
_v2InitMagCtrl,
_d2InitCtrl,
_pg2Ctrl,
_qg2Ctrl,
_pd2Ctrl,
_qd2Ctrl,
_tolCtrl,
_maxIterCtrl,
]) {
if (c.text.trim().isEmpty) return true;
}
if (!_iterateUntilConverge && _kTimesCtrl.text.trim().isEmpty) return true;
return false;
}

// Solve 
void _compute() {
setState(() {
_error = null;
res = null;
_showAllWorkings = false;
_openStep = -1;
});

// Bus 1 must be slack for this 2-bus solver
if (_bus1Type != BusType.slack) {
setState(() {
_error =
'This 2-bus solver keeps Bus 1 as SLACK (Vδ).\n'
'Change Bus 1 dropdown back to SLACK to compute.';
});
return;
}

try {
if (_anyEmpty()) {
ScaffoldMessenger.of(context).showSnackBar(
const SnackBar(content: Text('Please enter all inputs before computing.')),
);
return;
}

final sBaseMVA = _p(_sBaseCtrl, 100.0);
final vBaseKV = _p(_vBaseCtrl, 230.0);

final r12 = _p(_r12Ctrl, 0.0);
final x12 = _p(_x12Ctrl, 0.0);
final ypImag = _p(_ypCtrl, 0.0);

final v1Mag = _p(_v1MagCtrl, 1.0);
final d1Deg = _p(_d1Ctrl, 0.0);

final v2SpecOrInitMag = _p(_v2InitMagCtrl, 1.0);
final d2InitDeg = _p(_d2InitCtrl, 0.0);

final tol = _p(_tolCtrl, 1e-4);
final maxIterUI = _pi(_maxIterCtrl, 50).clamp(1, 500);
final kTimesUI = _pi(_kTimesCtrl, 2).clamp(1, 500);

// Bus 1 given powers
final pg1 = _p(_pg1Ctrl, 0.0);
final qg1 = _p(_qg1Ctrl, 0.0);
final pd1 = _p(_pd1Ctrl, 0.0);
final qd1 = _p(_qd1Ctrl, 0.0);

// Bus 2 powers
final pg2 = _p(_pg2Ctrl, 0.0);
final qg2 = _p(_qg2Ctrl, 0.0);
final pd2 = _p(_pd2Ctrl, 0.0);
final qd2 = _p(_qd2Ctrl, 0.0);

final qg2Min = _pOpt(_qg2MinCtrl);
final qg2Max = _pOpt(_qg2MaxCtrl);

final ip = NR2Inputs(
lineDataInPu: _lineDataInPu,
bus1PowerInPu: _bus1PowerInPu,
bus2PowerInPu: _bus2PowerInPu,
iterateUntilConverge: _iterateUntilConverge,
kTimesUI: kTimesUI,
bus2Type: _bus2Type,
bus1Given: _bus1Given,
sBaseMVA: sBaseMVA,
vBaseKV: vBaseKV,
r12: r12,
x12: x12,
ypImag: ypImag,
v1Mag: v1Mag,
d1Deg: d1Deg,
pg1: pg1,
qg1: qg1,
pd1: pd1,
qd1: qd1,
v2Mag: v2SpecOrInitMag,
d2Deg: d2InitDeg,
pg2: pg2,
qg2: qg2,
pd2: pd2,
qd2: qd2,
qg2Min: qg2Min,
qg2Max: qg2Max,
tol: tol,
maxIterUI: maxIterUI,
);

final out = solveNr2WithWorkings(ip);

setState(() {
res = out;
});
} catch (e) {
setState(() => _error = 'Error while solving: $e');
}
}

@override
void dispose() {
for (final c in [
_sBaseCtrl,
_vBaseCtrl,
_r12Ctrl,
_x12Ctrl,
_ypCtrl,
_v1MagCtrl,
_d1Ctrl,
_pg1Ctrl,
_qg1Ctrl,
_pd1Ctrl,
_qd1Ctrl,
_v2InitMagCtrl,
_d2InitCtrl,
_pg2Ctrl,
_qg2Ctrl,
_pd2Ctrl,
_qd2Ctrl,
_qg2MinCtrl,
_qg2MaxCtrl,
_tolCtrl,
_maxIterCtrl,
_kTimesCtrl,
]) {
c.dispose();
}
super.dispose();
}

@override
void initState() {
super.initState();

void listen(TextEditingController c) {
c.addListener(() {
if (!mounted) return;
setState(() {}); 
});
}

// Inputs that affect the solve (not iteration controls)
for (final c in [
_r12Ctrl,
_x12Ctrl,
_ypCtrl,

_v1MagCtrl,
_d1Ctrl,
_pg1Ctrl,
_qg1Ctrl,
_pd1Ctrl,
_qd1Ctrl,

_v2InitMagCtrl,
_d2InitCtrl,
_pg2Ctrl,
_qg2Ctrl,
_pd2Ctrl,
_qd2Ctrl,

_qg2MinCtrl,
_qg2MaxCtrl,
]) {
listen(c);
}
}

// MAIN BUILD 
@override
Widget build(BuildContext context) {
return Scaffold(
appBar: AppBar(
title: const Text('Newton–Raphson 2 Bus Solver'),
),
body: ListView(
padding: const EdgeInsets.all(16),
children: [
_busTypesExplainer(),
const SizedBox(height: 18),
_inputsCard(),
const SizedBox(height: 12),
Wrap(spacing: 8, runSpacing: 8, children: [
FilledButton(onPressed: _compute, child: const Text('Compute')),
FilledButton.tonal(
onPressed: () => setState(() => mode = DisplayMode.rect),
child: const Text('Show Rect'),
),
FilledButton.tonal(
onPressed: () => setState(() => mode = DisplayMode.polar),
child: const Text('Show Polar'),
),
FilledButton.tonal(
onPressed: () => setState(() => mode = DisplayMode.both),
child: const Text('Show Both'),
),
]),
const SizedBox(height: 16),
if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
if (res != null) _steps(res!),
if (res == null && _error == null)
const Padding(
padding: EdgeInsets.only(top: 28),
child: Center(
child: Text('Enter data and tap Compute to see the step-by-step workings.'),
),
),
],
),
);
}

// Explainer card 
Widget _busTypesExplainer() {
return Card(
elevation: 0.6,
child: Padding(
padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
const Text(
'Bus Types & What You Solve',
style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
),
const SizedBox(height: 10),
latexLeft([
r'\textbf{Core idea}',
r'\textbf{Flat start: }\text{if Bus 2 is a load bus (PQ), set }|\vec V_2^{(0)}|=1,\ \delta_2^{(0)}=0^\circ.',
r'\textbf{But, If Bus 2 is a PV (generator) bus, set }|\vec V_2^{(0)}|=|V_2|_{\text{spec}},\ \delta_2^{(0)}=\delta_{2,\text{spec}}\ (\text{use }0^\circ\text{ if not given}).',
r'\textbf{Slack bus (Always Bus 1): }\text{set }|\vec V_1|=1,\ \delta_1=0^\circ\ \text{for all cases}.',
r'\textbf{Line Impedance }(\vec z_{ij}=R_{ij}+jX_{ij}):\ \text{impedance of the line between buses }i\text{ and }j.',
r'\textbf{Shunt Charging Admittance }(\vec y_p):\ \text{line shunt charging admittance connected to ground (only for 2-bus } \pi \text{-model).}',
r'\text{Each bus carries four quantities: }V\ (\text{Magnitude}),\ \delta\ (\text{Phase angle of Voltage}),\ P\ (\text{Active Power}),\ Q\ (\text{Reactive Power}).',
r'\text{Net complex power at bus }i:\;\vec S_i=P_i+jQ_i=\vec S_{Gi}-\vec S_{Di}.',
r'\vec S_{Gi}=P_{Gi}+jQ_{Gi}.',
r'\vec S_{Di}=P_{Di}+jQ_{Di}.',
r'\text{Slack bus: }|\vec V|,\delta\ \text{specified; solve }P,Q.',
r'\text{PQ bus: }P,Q\ \text{specified; solve }|\vec V|,\delta.',
r'\text{PV bus: }P,|\vec V|\ \text{specified; solve }Q,\delta\ (\text{with Q-limits}).',
], size: 16.5),
const SizedBox(height: 10),
latexBlock([
r'\textbf{2-bus tutorial (slack + PQ / PV)}',
r'\begin{array}{|l|c|c|}\hline',
r'\textbf{Bus} & \textbf{Specified} & \textbf{Solve} \\ \hline',
r'\text{Bus 1 (Slack)} & |\vec V_1|,\ \delta_1 & P_1,\ Q_1 \\ \hline',
r'\text{Bus 2 (PQ)} & P_2,\ Q_2 & |\vec V_2|,\ \delta_2 \\ \hline',
r'\text{Bus 2 (PV)} & P_2,\ |\vec V_2| & Q_2,\ \delta_2 \\ \hline',
r'\end{array}',
], size: 16),
],
),
),
);
}

// LaTeX helpers for input UI 
Widget _lt(
String latex, {
double size = 14,
FontWeight? weight,
Color? color,
}) {
return Align(
alignment: Alignment.centerLeft,
child: FittedBox(
fit: BoxFit.scaleDown,
alignment: Alignment.centerLeft,
child: Math.tex(
latex,
mathStyle: MathStyle.text,
textStyle: TextStyle(
fontSize: size,
fontWeight: weight,
color: color,
height: 1.1,
),
),
),
);
}

Widget _ltMenu(
String latex, {
double size = 14,
FontWeight? weight,
Color? color,
}) {
return Math.tex(
latex,
mathStyle: MathStyle.text,
textStyle: TextStyle(
fontSize: size,
fontWeight: weight,
color: color,
height: 1.1,
),
);
}

Widget _latexNumField(
TextEditingController controller,
String latexLabel, {
double width = 180,
bool enabled = true,
}) {
const double labelHeight = 26;
const double gap = 4;

return SizedBox(
width: width,
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
SizedBox(
height: labelHeight,
child: Align(
alignment: Alignment.centerLeft,
child: _lt(latexLabel, size: 18, color: Colors.grey[800]),
),
),
const SizedBox(height: gap),
TextField(
controller: controller,
enabled: enabled,
decoration: const InputDecoration(
border: OutlineInputBorder(),
isDense: true,
),
style: const TextStyle(fontSize: 16),
keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
inputFormatters: [
FilteringTextInputFormatter.allow(RegExp(r'[-0-9.eE+]')),
],
),
],
),
);
}

Widget _latexDropdown<T>({
required T value,
required List<T> values,
required String Function(T) latexOf,
required ValueChanged<T?> onChanged,
double minWidth = 170,
}) {
return DropdownButton<T>(
value: value,
items: values
.map(
(t) => DropdownMenuItem<T>(
value: t,
child: ConstrainedBox(
constraints: BoxConstraints(minWidth: minWidth),
child: _ltMenu(latexOf(t), size: 17.0),
),
),
)
.toList(),
onChanged: onChanged,
);
}

String _busTypeLatex(BusType t) {
switch (t) {
case BusType.slack:
return r'\text{SLACK }(V\angle\delta)';
case BusType.pq:
return r'\text{LOAD }(PQ)';
case BusType.pv:
return r'\text{GENERATOR }(PV)';
}
}

String _bus1GivenLatex(Bus1Given g) {
switch (g) {
case Bus1Given.none:
return r'\text{None (optional)}';
case Bus1Given.sg1:
return r'\vec S_{g1}\ \text{is given}';
case Bus1Given.sd1:
return r'\vec S_{d1}\ \text{is given}';
}
}

// 2-bus diagram 
Widget _twoBusDiagramCard() {
// Read current values 
final r12 = _p(_r12Ctrl, 0.0);
final x12 = _p(_x12Ctrl, 0.0);
final yp = _p(_ypCtrl, 0.0);

final v1mag = _p(_v1MagCtrl, 1.0);
final d1deg = _p(_d1Ctrl, 0.0);

final pg1 = _p(_pg1Ctrl, 0.0);
final qg1 = _p(_qg1Ctrl, 0.0);
final pd1 = _p(_pd1Ctrl, 0.0);
final qd1 = _p(_qd1Ctrl, 0.0);

final v2mag = _p(_v2InitMagCtrl, 1.0);
final d2deg = _p(_d2InitCtrl, 0.0);

final pg2 = _p(_pg2Ctrl, 0.0);
final qg2 = _p(_qg2Ctrl, 0.0);
final pd2 = _p(_pd2Ctrl, 0.0);
final qd2 = _p(_qd2Ctrl, 0.0);

final qg2min = _pOpt(_qg2MinCtrl);
final qg2max = _pOpt(_qg2MaxCtrl);

String s(double v) => sig(v, 4);

String sComplexPQ(double p, double q, bool inPu) {
if (inPu) {
return s(p) + r'+j' + s(q) + r'\ \text{pu}';
}
return s(p) + r'\ \text{MW}+j' + s(q) + r'\ \text{Mvar}';
}

// Line parameters
final z12Latex = _lineDataInPu
? r'\vec z_{12}=' + s(r12) + r'+j' + s(x12) + r'\ \text{pu}'
: r'\vec z_{12}=' + s(r12) + r'+j' + s(x12) + r'\ \Omega';

final ypLatex = _lineDataInPu
? r'\vec y_p=j' + s(yp) + r'\ \text{pu}'
: r'\vec y_p=j' + s(yp) + r'\ \text{S/ph}';

// Bus 1 voltage + powers
final v1Latex = r'\vec V_1=' + s(v1mag) + r'\angle ' + s(d1deg) + r'^\circ';
final sg1Latex = r'\vec S_{G1}=' + sComplexPQ(pg1, qg1, _bus1PowerInPu);
final sd1Latex = r'\vec S_{D1}=' + sComplexPQ(pd1, qd1, _bus1PowerInPu);

// Bus 2 voltage + powers 
final v2Latex = r'\vec V_2=' + s(v2mag) + r'\angle ' + s(d2deg) + r'^\circ';
final sg2Latex = r'\vec S_{G2}=' + sComplexPQ(pg2, qg2, _bus2PowerInPu);
final sd2Latex = r'\vec S_{D2}=' + sComplexPQ(pd2, qd2, _bus2PowerInPu);
// Show Qg2 limits only if user entered them
final qg2LimLatex = (qg2min == null && qg2max == null)
? null
: r'Q_{g2}\in[' +
(qg2min == null ? r'-\infty' : s(qg2min)) +
r',' +
(qg2max == null ? r'+\infty' : s(qg2max)) +
r']\ \text{pu}';

return Card(
elevation: 0.6,
child: Padding(
padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
const Text(
'System Diagram (dynamic labels)',
style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16.5),
),
const SizedBox(height: 10),
ClipRRect(
borderRadius: BorderRadius.circular(12),
child: Container(
color: Colors.white,
height: 190,
width: double.infinity,
child: LayoutBuilder(
builder: (context, constraints) {
  const double imgAspect = 3.0;

  final rect = _containRect(
    containerW: constraints.maxWidth,
    containerH: 190,
    imageAspect: imgAspect,
  );

  return Stack(
    children: [
      Positioned(
        left: rect.left,
        top: rect.top,
        width: rect.width,
        height: rect.height,
        child: Image.asset(
          'assets/diagrams/2bus_pi_model.png',
          fit: BoxFit.fill,
        ),
      ),

      // Line labels
      _diagLabelFrac(rect, x: 0.34, y: 0.25, latex: z12Latex, size: 16),
      _diagLabelFrac(rect, x: 0.33, y: 0.44, latex: ypLatex, size: 15),

      // Bus 1 labels
      _diagLabelFrac(rect, x: -0.14, y: 0.34, latex: v1Latex, size: 15),
      _diagLabelFrac(rect, x: -0.16, y: 0.15, latex: sg1Latex, size: 14),
      _diagLabelFrac(rect, x: -0.06, y: 0.78, latex: sd1Latex, size: 14),

      // Bus 2 labels
      _diagLabelFrac(rect, x: 0.87, y: 0.33, latex: v2Latex, size: 15),
      _diagLabelFrac(rect, x: 0.76, y: 0.15, latex: sg2Latex, size: 14),
      _diagLabelFrac(rect, x: 0.70, y: 0.78, latex: sd2Latex, size: 14),

      // Optional Q-limits
      if (qg2LimLatex != null)
        _diagLabelFrac(rect, x: 0.80, y: 0.50, latex: qg2LimLatex!, size: 13),
    ],
  );
},
),
),
),
const SizedBox(height: 10),
latexLeft(
[
r'\textbf{Note: }\vec y_p\ \text{is the shunt charging admittance (only applicable for 2-bus }\pi\text{-model).}',
],
size: 15.8,
),
],
),
),
);
}

// Inputs card — NR 2-bus (KEEP SAME AS GS STYLE + preset dropdown)
Widget _inputsCard() {
final isPV = _bus2Type == BusType.pv;

return Card(
child: Padding(
padding: const EdgeInsets.all(16),
child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
_lt(
r'\textbf{2-bus inputs (solver logic: Bus 1 = SLACK, Bus 2 = PQ or PV)}',
size: 15.0,
weight: FontWeight.w700,
),
const SizedBox(height: 10),

_twoBusDiagramCard(),
const SizedBox(height: 14),


// PRESET DROPDOWN (Quick Fill)
softBox(
Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
_lt(r'\textbf{Quick Fill Preset}', size: 17.0, weight: FontWeight.w700),
const SizedBox(height: 8),
Row(
  children: [
    Expanded(
      child: DropdownButtonFormField<NR2Preset>(
        isExpanded: true,
        value: _selectedPreset,
        decoration: const InputDecoration(
          labelText: 'Preset',
          isDense: true,
          border: OutlineInputBorder(),
        ),
        items: _presets
            .map((p) => DropdownMenuItem<NR2Preset>(
                  value: p,
                  child: Text(p.name, overflow: TextOverflow.ellipsis),
                ))
            .toList(),
        onChanged: (p) => setState(() => _selectedPreset = p),
      ),
    ),
    const SizedBox(width: 10),
    FilledButton(
      onPressed: (_selectedPreset == null)
          ? null
          : () {
              if (_selectedPreset!.name == 'Custom (keep current)') return;
              _applyPreset(_selectedPreset!);
            },
      child: const Text('Apply'),
    ),
    const SizedBox(width: 8),
    OutlinedButton(
      onPressed: () => setState(() => _selectedPreset = null),
      child: const Text('Clear'),
    ),
  ],
),
const SizedBox(height: 8),
const Text(
  'Tip: "Apply" overwrites the fields below using the preset values.\n'
  '"Clear" only unselects the dropdown (does not change fields).',
),
],
),
),
const SizedBox(height: 14),

// Base + line
_lt(r'\textbf{Base + line data}', size: 15.0, weight: FontWeight.w700),
const SizedBox(height: 8),
Row(children: [
_lt(r'\textbf{Line data already in per-unit?}', size: 15.0),
const SizedBox(width: 10),
Switch(
value: _lineDataInPu,
onChanged: (v) => setState(() => _lineDataInPu = v),
),
]),
const SizedBox(height: 10),

Wrap(spacing: 12, runSpacing: 12, children: [
_latexNumField(_sBaseCtrl, r'S_{\text{base}}\;(\text{MVA})', width: 180),
_latexNumField(_vBaseCtrl, r'V_{\text{base}}\;(\text{kV})', width: 180),
_latexNumField(
_r12Ctrl,
_lineDataInPu ? r'R_{12}\;(\text{pu})' : r'R_{12}\;(\Omega)',
width: 180,
),
_latexNumField(
_x12Ctrl,
_lineDataInPu ? r'X_{12}\;(\text{pu})' : r'X_{12}\;(\Omega)',
width: 180,
),
if (_lineDataInPu)
_latexNumField(_ypCtrl, r'y_p\;(\text{pu})', width: 180)
else
_latexNumField(_ypCtrl, r'y_p\;(\text{S/ph})', width: 180),
]),

const SizedBox(height: 18),

// Bus 1
Row(
children: [
_lt(r'\textbf{Bus 1}', size: 18.0, weight: FontWeight.w700),
const SizedBox(width: 12),
_latexDropdown<BusType>(
value: _bus1Type,
values: BusType.values,
latexOf: _busTypeLatex,
onChanged: (v) => setState(() => _bus1Type = BusType.slack),
),

const SizedBox(width: 16),
_lt(r'\text{Given at Bus 1:}', size: 18.0),
const SizedBox(width: 10),
_latexDropdown<Bus1Given>(
value: _bus1Given,
values: Bus1Given.values,
latexOf: _bus1GivenLatex,
onChanged: (v) => setState(() => _bus1Given = v ?? Bus1Given.none),
),
const Spacer(),
_lt(r'\text{Bus 1 powers in per unit (pu)?}', size: 18.0),
const SizedBox(width: 8),
Switch(
value: _bus1PowerInPu,
onChanged: (v) => setState(() => _bus1PowerInPu = v),
),
],
),
const SizedBox(height: 8),

Wrap(spacing: 12, runSpacing: 12, children: [
_latexNumField(_v1MagCtrl, r'|V_1|\;(\text{pu})', width: 180),
_latexNumField(_d1Ctrl, r'\delta_1\;({}^\circ)', width: 180),
]),

const SizedBox(height: 10),

Wrap(spacing: 12, runSpacing: 12, children: [
_latexNumField(
_pg1Ctrl,
_bus1PowerInPu ? r'P_{g1}\;(\text{pu})' : r'P_{g1}\;(\text{MW})',
width: 180,
),
_latexNumField(
_qg1Ctrl,
_bus1PowerInPu ? r'Q_{g1}\;(\text{pu})' : r'Q_{g1}\;(\text{Mvar})',
width: 180,
),
_latexNumField(
_pd1Ctrl,
_bus1PowerInPu ? r'P_{d1}\;(\text{pu})' : r'P_{d1}\;(\text{MW})',
width: 180,
),
_latexNumField(
_qd1Ctrl,
_bus1PowerInPu ? r'Q_{d1}\;(\text{pu})' : r'Q_{d1}\;(\text{Mvar})',
width: 180,
),
]),

const SizedBox(height: 18),

// Bus 2
Row(
children: [
_lt(r'\textbf{Bus 2}', size: 18.0, weight: FontWeight.w700),
const SizedBox(width: 12),
_latexDropdown<BusType>(
value: _bus2Type,
values: BusType.values,
latexOf: _busTypeLatex,
onChanged: (v) => setState(() => _bus2Type = v ?? BusType.pq),
),
const Spacer(),
_lt(r'\text{Bus 2 powers in per unit (pu)?}', size: 18.0),
const SizedBox(width: 8),
Switch(
value: _bus2PowerInPu,
onChanged: (v) => setState(() => _bus2PowerInPu = v),
),
],
),
const SizedBox(height: 8),

Wrap(spacing: 12, runSpacing: 12, children: [
_latexNumField(_v2InitMagCtrl, r'|V_2|\ (\text{pu})', width: 180),
_latexNumField(_d2InitCtrl, r'\delta_2\ ({}^\circ)', width: 180),
]),
const SizedBox(height: 10),

Wrap(spacing: 12, runSpacing: 12, children: [
_latexNumField(
_pg2Ctrl,
_bus2PowerInPu ? r'P_{g2}\;(\text{pu})' : r'P_{g2}\;(\text{MW})',
width: 180,
),
_latexNumField(
_qg2Ctrl,
_bus2PowerInPu ? r'Q_{g2}\;(\text{pu})' : r'Q_{g2}\;(\text{Mvar})',
width: 180,
),
_latexNumField(
_pd2Ctrl,
_bus2PowerInPu ? r'P_{d2}\;(\text{pu})' : r'P_{d2}\;(\text{MW})',
width: 180,
),
_latexNumField(
_qd2Ctrl,
_bus2PowerInPu ? r'Q_{d2}\;(\text{pu})' : r'Q_{d2}\;(\text{Mvar})',
width: 180,
),
]),

if (isPV) ...[
const SizedBox(height: 12),
_lt(
r'\textbf{PV Q-limits (generator-side, optional)}',
size: 18.0,
weight: FontWeight.w700,
),
const SizedBox(height: 8),
Wrap(spacing: 12, runSpacing: 12, children: [
_latexNumField(
_qg2MinCtrl,
_bus2PowerInPu ? r'Q_{g2,\min}\;(\text{pu})' : r'Q_{g2,\min}\;(\text{Mvar})',
width: 180,
),
_latexNumField(
_qg2MaxCtrl,
_bus2PowerInPu ? r'Q_{g2,\max}\;(\text{pu})' : r'Q_{g2,\max}\;(\text{Mvar})',
width: 180,
),
]),
],

const SizedBox(height: 18),

// Iteration settings
_lt(r'\textbf{Iteration settings}', size: 18.0, weight: FontWeight.w700),
const SizedBox(height: 8),

softBox(
Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
_lt(r'\textbf{Iteration modes}', size: 17.0, weight: FontWeight.w700),
const SizedBox(height: 6),
_lt(
r'\text{Convergence ON: stop when difference < Convergence Tolerance (or max iterations).}',
size: 16.0,
color: Colors.grey[700],
),
_lt(
r'\text{Convergence OFF: run exactly }k\text{ Newton–Raphson iterations.}',
size: 16.0,
color: Colors.grey[700],
),
]),
),
const SizedBox(height: 10),

Wrap(spacing: 12, runSpacing: 12, children: [
_latexNumField(
_tolCtrl,
r'\text{Convergence tolerance (max }|\Delta x|_{\max}\text{)}',
width: 300,
),
_latexNumField(_maxIterCtrl, r'\text{max iterations}', width: 300),
]),
const SizedBox(height: 12),

Row(
children: [
Switch(
value: _iterateUntilConverge,
onChanged: (v) => setState(() => _iterateUntilConverge = v),
),
const SizedBox(width: 10),
_lt(r'\text{Iterate until converge}', size: 18.0),
],
),

if (!_iterateUntilConverge) ...[
const SizedBox(height: 10),
softBox(
Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
  _lt(r'\textbf{Fixed-iteration mode}', size: 18.0, weight: FontWeight.w700),
  const SizedBox(height: 10),
  _latexNumField(_kTimesCtrl, r'\text{Number of iterations }(k)', width: 220),
  const SizedBox(height: 8),
  _lt(
    r'\text{When convergence is OFF, the solver will run exactly (k-times) Newton–Raphson iterations.}',
    size: 16.0,
    color: Colors.grey[700],
  ),
],
),
),
],
]),
),
);
}

// Steps UI (Show all / Close all)
Widget _buildStepsUI(List<Step> steps) {
final controls = Row(
children: [
FilledButton(
onPressed: () => setState(() {
_showAllWorkings = true;
_openStep = -1;
}),
child: const Text('Show all workings'),
),
const SizedBox(width: 10),
OutlinedButton(
onPressed: () => setState(() {
_showAllWorkings = false;
_openStep = -1;
}),
child: const Text('Close all workings'),
),
],
);

if (_showAllWorkings) {
return Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
controls,
const SizedBox(height: 12),
...List.generate(steps.length, (i) {
final s = steps[i];
final stepNo = i + 1;

return Padding(
padding: const EdgeInsets.only(bottom: 14),
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
  Row(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.indigo.withOpacity(0.12),
          border: Border.all(color: Colors.indigo.withOpacity(0.45)),
        ),
        alignment: Alignment.center,
        child: Text(
          '$stepNo',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: DefaultTextStyle(
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: Colors.red[700],
          ),
          child: s.title,
        ),
      ),
    ],
  ),
  if (s.subtitle != null)
    Padding(
      padding: const EdgeInsets.only(left: 36, top: 4),
      child: DefaultTextStyle(
        style: TextStyle(fontSize: 13.5, color: Colors.grey[700]),
        child: s.subtitle!,
      ),
    ),
  const SizedBox(height: 10),
  Padding(
    padding: const EdgeInsets.only(left: 36),
    child: s.content,
  ),
  const SizedBox(height: 10),
  Divider(color: Colors.grey.withOpacity(0.25)),
],
),
);
}),
],
);
}

return Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
controls,
const SizedBox(height: 12),
...List.generate(steps.length, (i) {
final s = steps[i];
final stepNo = i + 1;
final expanded = _openStep == i;

return Padding(
padding: const EdgeInsets.only(bottom: 10),
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
InkWell(
  borderRadius: BorderRadius.circular(10),
  onTap: () => setState(() {
    _openStep = expanded ? -1 : i;
  }),
  child: Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.indigo.withOpacity(0.12),
            border: Border.all(color: Colors.indigo.withOpacity(0.45)),
          ),
          alignment: Alignment.center,
          child: Text(
            '$stepNo',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: DefaultTextStyle(
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Colors.red[700],
            ),
            child: s.title,
          ),
        ),
        Icon(expanded ? Icons.expand_less : Icons.expand_more),
      ],
    ),
  ),
),
if (expanded) ...[
  if (s.subtitle != null)
    Padding(
      padding: const EdgeInsets.only(left: 36, top: 2),
      child: DefaultTextStyle(
        style: TextStyle(fontSize: 13.5, color: Colors.grey[700]),
        child: s.subtitle!,
      ),
    ),
  const SizedBox(height: 10),
  Padding(
    padding: const EdgeInsets.only(left: 36),
    child: s.content,
  ),
  const SizedBox(height: 10),
  Row(
    children: [
      FilledButton(
        onPressed: () => setState(() {
          if (_openStep < steps.length - 1) _openStep++;
        }),
        child: const Text('Continue'),
      ),
      const SizedBox(width: 10),
      TextButton(
        onPressed: () => setState(() {
          if (_openStep > 0) _openStep--;
        }),
        child: const Text('Cancel'),
      ),
    ],
  ),
  const SizedBox(height: 10),
],
Divider(color: Colors.grey.withOpacity(0.25)),
],
),
);
}),
],
);
}

// Step output
Widget _steps(NR2Result r) {
String rect(C z) {
final sgn = z.im >= 0 ? '+' : '-';
return '${sig(z.re)}\\, $sgn\\, j${sig(z.im.abs())}';
}

String polar(C z) => '${sig(z.abs())}\\angle ${sig(z.angDeg())}^{\\circ}';

String show(C z) {
if (mode == DisplayMode.rect) return rect(z);
if (mode == DisplayMode.polar) return polar(z);
return rect(z) + r'\;=\;' + polar(z);
}

String mat(List<List<C>> m, {required bool polarForm}) {
String cell(C z) => polarForm ? polar(z) : rectPretty(z);
final rows = m.map((row) => row.map(cell).join(r' & ')).join(r' \\ ');
return r'\begin{bmatrix}' + rows + r'\end{bmatrix}';
}

final Ybus = [
[r.Y11, r.Y12],
[r.Y21, r.Y22],
];

// Pre compute terms used for Step 6 & Step 7
final V1 = r.V1;
final V2f = r.V2final;

final Y11 = r.Y11;
final Y12 = r.Y12;

final y12 = r.y12Series;
final yp = r.yShunt;

// Step 6 (Slack power)
final I11_term = Y11 * V1;
final I12_term = Y12 * V2f;
final I1_sum = I11_term + I12_term;
final I1_star = I1_sum.conj();
final S1_calc = V1 * I1_star;

final P1pu = S1_calc.re;
final Q1pu = S1_calc.im;
final P1_MW = P1pu * r.sBaseMVA;
final Q1_Mvar = Q1pu * r.sBaseMVA;

// Step 7 (Line flows & losses)
final V1mV2 = V1 - V2f;
final V2mV1 = V2f - V1;

final I12_series = y12 * V1mV2;
final I12_shunt = yp * V1;
final I12_sum = I12_series + I12_shunt;

final I21_series = y12 * V2mV1;
final I21_shunt = yp * V2f;
final I21_sum = I21_series + I21_shunt;

final I12_star = I12_sum.conj();
final I21_star = I21_sum.conj();

final S12_calc = V1 * I12_star;
final S21_calc = V2f * I21_star;

final Sloss_calc = S12_calc + S21_calc;

final isPV = r.bus2Type == BusType.pv;

int n = 1;
Step mkStep(String title, Widget content) =>
Step(isActive: true, title: Text('${n++}) $title'), content: content);

final steps = <Step>[];

// Step 1: Convert line data to per-unit and build Y-bus
steps.add(
mkStep(
'Convert z (Line Impedance) → y (Line Admittance) and build Y Bus Admittance Matrix',
Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Builder(builder: (context) {
final bool hasShunt = (r.ypImag.abs() > 1e-12);

return Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
  latexBlock([r'\textbf{Goal: compute } \vec Y_{\text{bus}} \text{ for a 2-bus system.}'], size: 17),
  const SizedBox(height: 10),
  latexBlock([r'\textbf{Line Admittances (series)}'], size: 17),
  const SizedBox(height: 6),
  latexLeft([
    r'\text{We first need to find the Line Admittance }\Rightarrow\ \vec y_{ij}=\dfrac{1}{\vec z_{ij}}',
    r'\textbf{Line Impedance (given): }\ \vec z_{ij}=R_{ij}+jX_{ij}.',
  ], size: 16.5),
  const SizedBox(height: 10),
  softBox(
    latexLeft([
      r'\textbf{Terminology}',
      r'\text{Line Impedance }(\vec z_{ij}=R_{ij}+jX_{ij}):\ \text{impedance of the line between buses }i\text{ and }j.',
      r'\text{Line Admittance }(\vec y_{ij}):\ \text{series admittance of the line between buses.}',
      r'\text{Self-Admittance }(\vec Y_{ii}):\ \text{diagonal elements of }\mathbf{\vec Y}_{\text{bus}}\ =\ \text{sum of incident admittances (and shunt if present).}',
      r'\text{Mutual/Transfer Admittance }(\vec Y_{ij}):\ \text{off-diagonal elements.}',
    ], size: 16),
  ),
  const SizedBox(height: 10),
  warnBox(
    latexLeft([
      r'\text{If no line connects }i\text{ and }j,\ \vec y_{ij}=0\Rightarrow \vec Y_{ij}=\vec Y_{ji}=0.',
    ], size: 16),
  ),
  const SizedBox(height: 12),
  latexBlock([r'\textbf{Given (your inputs)}'], size: 17),
  const SizedBox(height: 8),
  latexLeft([
    r'S_{\text{base}}=' + sig(r.sBaseMVA) + r'\ \text{MVA},\quad V_{\text{base}}=' + sig(r.vBaseKV) + r'\ \text{kV}.',
    r'\vec z_{12}=' + sig(r.r12) + r' + j' + sig(r.x12) + (r.dataInPu ? r'\ (\text{pu})' : r'\ (\Omega)') + r'.',
    hasShunt
        ? (r'\vec y_p = j' + sig(r.ypImag) + (r.dataInPu ? r'\ (\text{pu})' : r'\ (\text{S/ph})') + r'.')
        : r'\vec y_p = 0 \ \Rightarrow\ \text{no line charging / shunt neglected.}',
  ], size: 16.5),
  const SizedBox(height: 10),
  if (r.dataInPu) ...[
    softBox(
      latexLeft([
        r'\textbf{Inputs already in per-unit}',
        r'\vec z_{12,\text{pu}}=' + show(r.z12Pu) + r'.',
        hasShunt ? (r'\vec y_{p,\text{pu}}=' + show(r.ypPu) + r'.') : r'\vec y_{p,\text{pu}}=0.',
      ], size: 16),
    ),
    const SizedBox(height: 12),
  ] else ...[
    warnBox(
      latexLeft([
        r'\textbf{Per-unit conversion}',
        r'Z_{\text{base}}=\dfrac{V_{\text{base}}^2}{S_{\text{base}}}=' +
            sig(r.zBase) +
            r'\ \Omega,\quad Y_{\text{base}}=\dfrac{1}{Z_{\text{base}}}=' +
            sig(r.yBase) +
            r'\ \text{S}.',
        r'\vec z_{12,\text{pu}}=\dfrac{\vec z_{12,\Omega}}{Z_{\text{base}}}=' + show(r.z12Pu) + r'.',
        hasShunt
            ? (r'\vec y_{p,\text{pu}}=\dfrac{\vec y_{p,\text{actual}}}{Y_{\text{base}}}=' + show(r.ypPu) + r'.')
            : r'\vec y_{p,\text{pu}}=0.',
      ], size: 16),
    ),
    const SizedBox(height: 12),
  ],
  latexBlock([r'\textbf{Line admittances (series)}'], size: 17),
  const SizedBox(height: 6),
  latexLeft([
    r'\vec y_{12}=\dfrac{1}{\vec z_{12,\text{pu}}}',
    r'\vec y_{12}=\dfrac{1}{(' + rect(r.z12Pu) + r')}=' + show(r.y12Series) + r'.',
  ], size: 16.5),
  const SizedBox(height: 12),
  latexBlock([r'\boxed{\textbf{Diagonals (Self-Admittance):}\ \vec Y_{ii}=\sum \vec y_{ij}\ \text{(plus shunt if present)}}'], size: 16.5),
  const SizedBox(height: 8),
  if (!hasShunt) ...[
    latexLeft([
      r'\text{Since }\vec y_p=0,\ \text{no shunt term is added.}',
      r'\vec Y_{11}=\vec y_{12}=(' +
          rect(r.y12Series) +
          r')=' +
          rect(r.Y11) +
          (mode == DisplayMode.rect ? r'.' : r'\;=\;' + polar(r.Y11) + r'.'),
      r'\vec Y_{22}=\vec y_{21}=\vec y_{12}=(' +
          rect(r.y12Series) +
          r')=' +
          rect(r.Y22) +
          (mode == DisplayMode.rect ? r'.' : r'\;=\;' + polar(r.Y22) + r'.'),
    ], size: 16.5),
  ] else ...[
    latexLeft([
      r'\textbf{Shunt present (}\pi\textbf{-model)}',
      r'\text{Identical shunt at each end: }\ \vec y_{\text{shunt at bus 1}}=\vec y_{\text{shunt at bus 2}}=\vec y_p.',
      r'\text{So the diagonals include shunt: }\ \vec Y_{11}=\vec y_{12}+\vec y_p,\quad \vec Y_{22}=\vec y_{12}+\vec y_p.',
      r'\vec Y_{11}=( ' +
          rect(r.y12Series) +
          r')+( ' +
          rect(r.ypPu) +
          r')=' +
          rect(r.Y11) +
          (mode == DisplayMode.rect ? r'.' : r'\;=\;' + polar(r.Y11) + r'.'),
      r'\vec Y_{22}=( ' +
          rect(r.y12Series) +
          r')+( ' +
          rect(r.ypPu) +
          r')=' +
          rect(r.Y22) +
          (mode == DisplayMode.rect ? r'.' : r'\;=\;' + polar(r.Y22) + r'.'),
    ], size: 16.5),
  ],
  const SizedBox(height: 12),
  latexBlock([r'\boxed{\textbf{Off-Diagonals (Mutual/Transfer Admittance):}\ \vec Y_{ij}=-\vec y_{ij}\ (i\neq j)}'], size: 16.5),
  const SizedBox(height: 8),
  latexLeft([
    r'\vec Y_{12}=\vec Y_{21}=-\vec y_{12}=-( ' +
        rect(r.y12Series) +
        r')=' +
        rect(r.Y12) +
        (mode == DisplayMode.rect ? r'.' : r'\;=\;' + polar(r.Y12) + r'.'),
  ], size: 16.5),
  const SizedBox(height: 14),
  latexBlock([
    hasShunt
        ? r'\textbf{Build }\mathbf{\vec Y}_{\text{bus}}\textbf{ (}\pi\textbf{-model shunt included)}'
        : r'\textbf{Build }\mathbf{\vec Y}_{\text{bus}}\textbf{ (no line charging / shunt neglected)}',
    r'\vec Y_{ii}=\sum \vec y_{ij},\quad \vec Y_{ij}=-\vec y_{ij}\ (i\ne j).',
  ], size: 16.5),
  const SizedBox(height: 10),
  if (mode == DisplayMode.both) ...[
    latexBlock([r'\mathbf{\vec Y}_{\text{bus}}^{\text{rect}}=' + mat(Ybus, polarForm: false)]),
    const SizedBox(height: 10),
    latexBlock([r'\mathbf{\vec Y}_{\text{bus}}^{\text{polar}}=' + mat(Ybus, polarForm: true)]),
  ] else ...[
    latexBlock([
      r'\mathbf{\vec Y}_{\text{bus}}=' +
          (mode == DisplayMode.rect ? mat(Ybus, polarForm: false) : mat(Ybus, polarForm: true))
    ]),
  ],
],
);
}),
],
),
),
);

// Step 2: Specify buses, convert powers to pu and set initial voltages
steps.add(
mkStep(
'Specify buses, convert powers to pu, and set initial voltages',
Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
latexLeft([
r'\textbf{Bus types (from your dropdowns)}',
r'\text{Bus 1: Slack (V}\delta\text{),\quad Bus 2: }' + (isPV ? r'\text{PV}.' : r'\text{PQ}.'),
r'',
r'\textbf{Net complex power definition: }',
r'\vec S_i=\vec S_{Gi}-\vec S_{Di}.',
r'\vec S_{Gi}=P_{Gi}+jQ_{Gi}.',
r'\vec S_{Di}=P_{Di}+jQ_{Di}.',
r'\vec S_1=\vec S_{G1}-\vec S_{D1}=(P_{G1}-P_{D1})+j(Q_{G1}-Q_{D1}).',
r'',
r'\text{(Recall: apparent power } \vec S = P + jQ,\ \text{with }P=\text{real power and }Q=\text{reactive power.)}',
r'\text{For Gauss–Seidel power-flow questions (2-bus or 3-bus), it is best to express all } \vec S \text{ values in per-unit (pu).}',
r'',
r'\textbf{Slack bus (Bus 1)}',
r'\vec V_1 = |\vec V_1|\angle \delta_1 = ' + show(r.V1) + r'.',
r'\textbf{Slack extra info (optional): }' +
  (r.bus1Given == Bus1Given.sg1
      ? r'\text{You selected “}S_{G1}\text{ is given” (we will solve }S_{D1}\text{ using }S_1=S_{G1}-S_{D1}\text{).}'
      : (r.bus1Given == Bus1Given.sd1
          ? r'\text{You selected “}S_{D1}\text{ is given” (we will solve }S_{G1}\text{ using }S_1=S_{G1}-S_{D1}\text{).}'
          : r'\text{None selected (we treat entered }S_{D1}\text{ as given; default is 0).}')),
], size: 16.5),
const SizedBox(height: 10),
  softBox(
latexLeft([
r'\textbf{Bus 2 conversion}',
if (!_bus2PowerInPu) ...[
  r'P_{d2,\text{pu}}=\dfrac{P_{d2,\text{MW actual}}}{S_{\text{base}}}'
      r'=\dfrac{' +
      sig(double.tryParse(_pd2Ctrl.text) ?? 0) +
      r'}{' +
      sig(r.sBaseMVA) +
      r'}=' +
      sig(r.Sd2.re) +
      r'\ \text{pu}.',
  r'Q_{d2,\text{pu}}=\dfrac{Q_{d2,\text{Mvar actual}}}{S_{\text{base}}}'
      r'=\dfrac{' +
      sig(double.tryParse(_qd2Ctrl.text) ?? 0) +
      r'}{' +
      sig(r.sBaseMVA) +
      r'}=' +
      sig(r.Sd2.im) +
      r'\ \text{pu}.',
] else ...[
  r'\text{Inputs already in per-unit: }'
      r'P_{d2,\text{pu}}=' +
      sig(r.Sd2.re) +
      r',\ Q_{d2,\text{pu}}=' +
      sig(r.Sd2.im) +
      r',\ P_{g2,\text{pu}}=' +
      sig(r.Sg2_in.re) +
      r',\ Q_{g2,\text{pu}}=' +
      sig(r.Sg2_in.im) +
      r'.',
],
r'\vec S_{D2}=P_{d2, pu}+jQ_{d2, pu}=' + show(r.Sd2) + r'.',
r'\vec S_{G2}=P_{g2, pu}+jQ_{g2, pu}=' + show(r.Sg2_in) + r'.',
if (!isPV) ...[
  r'\Rightarrow\ \vec S_2=\vec S_{G2}-\vec S_{D2}=' + show(r.S2_userPQ) + r'.',
] else ...[
  r'\textbf{(PV)}\ \text{Only }P_2\text{ and }|\vec V_2|\text{ are specified; }Q_2\text{ will be computed.}',
  r'P_2=P_{g2}-P_{d2}=' +
      sig(r.Sg2_in.re) +
      r'-' +
      sig(r.Sd2.re) +
      r'=' +
      sig(r.P2spec) +
      r'.',
  r'|\vec V_2|_{\text{spec}}=' + sig(r.V2spec) + r'.',
],
], size: 16),
),
const SizedBox(height: 12),

latexLeft([
r'\textbf{Voltages (phasors)}',
r'\vec V_1=|\vec V_1|\angle\delta_1=' + show(r.V1) + r'\quad (\text{reference voltage}).',
r'\textbf{Remember to Set Flat Start }\;1\angle 0^\circ\;\textbf{ (For PQ, Load Buses), if not:}',
r'\vec V_2^{(0)}=' + show(r.V20_user) + r'.',
], size: 16.5),
],
),
),
);

// Step 3: PV reactive power and Q-limits
if (isPV) {
steps.add(
mkStep(
'PV reactive power and Q-limits (generator side)',
Builder(
builder: (context) {
String showStep3(C z) => show(z);

final C V1 = r.V1;
final C V2_0 = r.V20_user;

final C Y21 = r.Y21;
final C Y22 = r.Y22;

final double Qd2 = r.Sd2.im;

final C term21_0 = Y21 * V1;
final C term22_0 = Y22 * V2_0;

final C sumY2_0 = term21_0 + term22_0;

final C V2c_0 = V2_0.conj();
final C prodPV2_0 = V2c_0 * sumY2_0;

final double q2Raw_0 = -prodPV2_0.im;

final double qg2Raw_0 = q2Raw_0 + Qd2;

final double? qg2min = r.qg2min;
final double? qg2max = r.qg2max;

bool qg2LowViol_0 = false;
bool qg2HighViol_0 = false;

double qg2Used_0 = qg2Raw_0;

if (qg2min != null && qg2Used_0 < qg2min) {
qg2LowViol_0 = true;
qg2Used_0 = qg2min;
}
if (qg2max != null && qg2Used_0 > qg2max) {
qg2HighViol_0 = true;
qg2Used_0 = qg2max;
}

final double q2Used_0 = qg2Used_0 - Qd2;

final bool pvDroppedToPQ_at0 = (qg2LowViol_0 || qg2HighViol_0);

return Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
  latexLeft([
    r'\textbf{General PV reactive-power update (Q)}',
    r'Q_i^{(k+1)}=-\,\mathrm{Im}\!\left\{(\vec V_i^{(k)})^{*}\sum_{j=1}^{i-1}\vec Y_{ij}\vec V_j^{(k+1)}+(\vec V_i^{(k)})^{*}\sum_{j=i}^{n}\vec Y_{ij}\vec V_j^{(k)}\right\},'
        r'\quad i=m+1,\ldots,n.',
    r'',
    r'\textbf{For 2-bus PV (bus 2):}',
    r'Q_2^{(k+1)}=-\,\mathrm{Im}\!\left\{(\vec V_{2}^{(k)})^{*}\Big(\vec Y_{21}\vec V_{1}+\vec Y_{22}\vec V_{2}^{(k)}\Big)\right\}.',
    r'',
    r'\textbf{Limits are on generator-side }Q_{g2}:',
    r'\vec S_2=\vec S_{g2}-\vec S_{d2}\Rightarrow Q_2=Q_{g2}-Q_{d2}\Rightarrow Q_{g2}=Q_2+Q_{d2}.',
    r'',
    r'\textbf{Worked example at }k=0\textbf{ (your inputs)}',
    r'\vec V_1=' + showStep3(V1) + r',\quad \vec V_2^{(0)}=' + showStep3(V2_0) + r'.',
    r'\vec Y_{21}=' + showStep3(Y21) + r',\quad \vec Y_{22}=' + showStep3(Y22) + r'.',
    r'Q_{d2}=' + sig(Qd2) + r'.',
    r'',
    r'\textbf{1) Form neighbour terms}',
    r'\vec Y_{21}\vec V_1'
        r'=\big(' + rect(Y21) + r'\big)\big(' + rect(V1) + r'\big)'
        r'=' + showStep3(term21_0) + r'.',
    r'\vec Y_{22}\vec V_2^{(0)}'
        r'=\big(' + rect(Y22) + r'\big)\big(' + rect(V2_0) + r'\big)'
        r'=' + showStep3(term22_0) + r'.',
    r'',
    r'\textbf{2) Sum neighbours:}',
    r'\vec Y_{21}\vec V_1+\vec Y_{22}\vec V_2^{(0)}=' + showStep3(sumY2_0) + r'.',
    r'',
    r'\textbf{3) Multiply by }(\vec V_2^{(0)})^{*}:',
    r'(\vec V_2^{(0)})^{*}=' + showStep3(V2c_0) + r'.',
    r'(\vec V_2^{(0)})^{*}\Big(\vec Y_{21}\vec V_1+\vec Y_{22}\vec V_2^{(0)}\Big)='
        r'\big(' + rect(V2_0.conj()) + r'\big)\big(' + rect(sumY2_0) + r'\big)='
        + showStep3(prodPV2_0) + r'.',
    r'',
    r'\textbf{4) Take the negative imaginary part:}',
    r'Q_2^{(1)}=-\mathrm{Im}\{' + rect(prodPV2_0) + r'\}=' + sig(q2Raw_0) + r'.',
    r'',
    r'\textbf{5) Convert to generator-side }Q_{g2}:',
    r'Q_{g2}^{(1)}=Q_2^{(1)}+Q_{d2}=' + sig(q2Raw_0) + r'+' + sig(Qd2) + r'=' + sig(qg2Raw_0) + r'.',
    r'',
    r'\color{red}{\underline{\textbf{6) Check generator Q-limits (if provided)}}}',
    r'\text{If }Q_{g2}^{(k+1)}<Q_{g2,\min}\Rightarrow Q_{g2}:=Q_{g2,\min},\qquad'
        r'\text{If }Q_{g2}^{(k+1)}>Q_{g2,\max}\Rightarrow Q_{g2}:=Q_{g2,\max}.',
    (qg2min == null && qg2max == null)
        ? r'\textbf{No Q-limits were provided, so we do not update.}'
        : (qg2LowViol_0
            ? (r'\textbf{Violation: }Q_{g2}^{(1)}<Q_{g2,\min}\Rightarrow Q_{g2}=Q_{g2,\min}=' +
                sig(qg2min!) +
                r'.')
            : (qg2HighViol_0
                ? (r'\textbf{Violation: }Q_{g2}^{(1)}>Q_{g2,\max}\Rightarrow Q_{g2}=Q_{g2,\max}=' +
                    sig(qg2max!) +
                    r'.')
                : r'\textbf{Within limits: }Q_{g2}\text{ unchanged.}')),
    r'\textbf{Generator-side Q used: }Q_{g2}=' + sig(qg2Used_0, 5) + r'.',
    r'',
    r'\textbf{7) Convert back to net }Q_2\textbf{ for use in the solver:}',
    r'Q_2=Q_{g2}-Q_{d2}=' + sig(qg2Used_0) + r'-' + sig(Qd2) + r'=' + sig(q2Used_0) + r'.',
    r'',
    if (pvDroppedToPQ_at0) ...[
      r'\textbf{Because of violation: PV }\rightarrow\textbf{ PQ before Newton–Raphson starts}',
      r'\text{Fix }Q_2:= ' + sig(q2Used_0) + r'\text{ and then treat Bus 2 as a PQ bus in Step 4.}',
      r'\textbf{Use flat start for NR: }\vec V_2^{(0)}:=1\angle 0^\circ.',
    ] else ...[
      r'\textbf{No violation: keep PV for Newton–Raphson}',
      r'\text{Proceed to Step 4 solving for }\delta_2\text{ (with }|V_2|\text{ fixed to }|V_2|_{\text{spec}}\text{).}',
    ],
  ], size: 16.2),
],
);
},
),
),
);
}

// // Step 4: GS update for V2 and first Gauss–Seidel Iteration 
steps.add(
mkStep(
'Newton–Raphson technique',
Builder(
builder: (context) {
Widget mLeft(List<String> lines, {double size = 16}) {
return SizedBox(
width: double.infinity,
child: Align(
  alignment: Alignment.centerLeft,
  child: latexLeft(lines, size: size),
),
);
}

double deg2rad(double d) => d * math.pi / 180.0;
double rad2deg(double r) => r * 180.0 / math.pi;
String f6(num x) => x.toDouble().toStringAsFixed(6);

final double y21mag = r.Y21.abs();
final double g21deg = r.Y21.angDeg();
final double y22mag = r.Y22.abs();
final double g22deg = r.Y22.angDeg();

final bool pvUser = (r.bus2Type == BusType.pv);
final bool dropped = r.droppedToPQ;
final bool pvActive = pvUser && !dropped;

final double V1mag = r.V1.abs();
final double d1deg = r.V1.angDeg();

final double V20_used = (pvUser && dropped) ? 1.0 : r.V20_user.abs();
final double d20deg_used = (pvUser && dropped) ? 0.0 : r.V20_user.angDeg();

final double Q2specUsed = pvActive
? 0.0
: (dropped ? (r.Q2fixedFromLimit ?? r.Q2spec_user) : r.Q2spec_user);

final double theta0deg = d20deg_used - d1deg - g21deg;
final double cosT0 = math.cos(deg2rad(theta0deg));
final double sinT0 = math.sin(deg2rad(theta0deg));

final double cosG22 = math.cos(deg2rad(g22deg));
final double sinG22 = math.sin(deg2rad(g22deg));

final double p20 =
(y21mag * V1mag * V20_used * cosT0) +
(y22mag * (V20_used * V20_used) * cosG22);

final double q20 =
(y21mag * V1mag * V20_used * sinT0) -
(y22mag * (V20_used * V20_used) * sinG22);

final double dP0 = r.P2spec - p20;
final double dQ0 = pvActive ? 0.0 : (Q2specUsed - q20);

final double J11 = -y21mag * V1mag * V20_used * sinT0;
final double J12 =
(y21mag * V1mag * cosT0) +
(2.0 * y22mag * V20_used * cosG22);
final double J21 = (y21mag * V1mag * V20_used * cosT0);
final double J22 =
(y21mag * V1mag * sinT0) -
(2.0 * y22mag * V20_used * sinG22);

double dDel0 = 0.0;
double dV0 = 0.0;

double detJ = 0.0;
double inv11 = 0.0, inv12 = 0.0, inv21 = 0.0, inv22 = 0.0;

if (pvActive) {
dDel0 = (J11.abs() < 1e-14) ? 0.0 : (dP0 / J11);
dV0 = 0.0;
} else {
detJ = (J11 * J22) - (J12 * J21);

if (detJ.abs() < 1e-14) {
dDel0 = 0.0;
dV0 = 0.0;
} else {
inv11 = J22 / detJ;
inv12 = -J12 / detJ;
inv21 = -J21 / detJ;
inv22 = J11 / detJ;

dDel0 = inv11 * dP0 + inv12 * dQ0;
dV0 = inv21 * dP0 + inv22 * dQ0;
}
}

final double d21_next_deg = d20deg_used + rad2deg(dDel0);
final double V21_next = pvActive ? r.V2spec : (V20_used + dV0);

final int nBus = 2;
final int ng = pvUser ? 1 : 0;
final int nUnknown = 2 * (nBus - 1) - ng;

return Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
const SizedBox(height: 6),

latexBlock(
  [
    r'\textbf{Goal: apply Newton–Raphson (NR) to solve the power-flow at Bus 2.}',
    r'\text{Flow in this step: }\ \textbf{formulas}\rightarrow\textbf{mismatch}\rightarrow\textbf{Jacobian}\rightarrow\textbf{update}.',
  ],
  size: 17,
),
const SizedBox(height: 10),

softBox(
  Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      mLeft([
        r'\textbf{How many independent unknowns: }=2(n_{\text{bus}}-1)-n_g.',
        r'\text{Here }n_{\text{bus}}=2,\ n_g=' +
            (pvUser ? r'1\ (\text{Bus 2 is PV})' : r'0\ (\text{Bus 2 is PQ})') +
            r'\Rightarrow \text{Number of independent unknowns} =' +
            nUnknown.toString() +
            r'.',
        r'',
        pvUser
            ? r'\textbf{PV case: }P_2,\ |V_2|\text{ specified}\Rightarrow \text{unknown is }\delta_2.'
            : r'\textbf{PQ case: }P_2,\ Q_2\text{ specified}\Rightarrow \text{unknowns are }\delta_2\text{ and }|V_2|.',
        r'',
        r'\textbf{Power equations (polar):}',
        r'P_i=|V_i|\sum_{j=1}^{n_{\text{bus}}}|V_j||Y_{ij}|\cos(\delta_i-\delta_j-\gamma_{ij}).',
        r'Q_i=|V_i|\sum_{j=1}^{n_{\text{bus}}}|V_j||Y_{ij}|\sin(\delta_i-\delta_j-\gamma_{ij}).',
        r'',
        r'\textbf{Index meaning:}',
        r'i:\ \text{the bus we are solving (here }i=2\text{).}',
        r'j:\ \text{other buses connected to bus }i\ (\text{terms }Y_{ij});\ \text{here the sum uses }j=1,2.',
        r'',
        r'\color{red}{\textbf{Important: }Y_{ij}=|Y_{ij}|\angle\gamma_{ij}\ \text{comes from }\mathbf{Y}_{bus}.}',
        r'\color{red}{\textbf{So “small angles” }\gamma_{21},\gamma_{22}\textbf{ are the angles of }Y_{21},Y_{22}\textbf{ in }\mathbf{Y}_{bus}.}',
      ], size: 16),
    ],
  ),
),

const SizedBox(height: 12),

warnBox(
  Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      mLeft([
        r'\textbf{NR mismatch equation (matrix form)}',
        r'',
        r'\textbf{Power mismatch vector: }\Delta\vec u^{(k)}='
            r'\begin{bmatrix}\Delta P_2^{(k)}\\[2pt]\Delta Q_2^{(k)}\end{bmatrix}'
            r'=\begin{bmatrix}P_{2,\text{spec}}-p_2^{(k)}\\[2pt]Q_{2,\text{spec}}-q_2^{(k)}\end{bmatrix}.',
        pvActive
            ? r'\textbf{State update vector (For PV Bus): }\Delta\vec x^{(k)}='
                r'\begin{bmatrix}\Delta\delta_2^{(k)}\end{bmatrix}.'
            : r'\textbf{State update vector (For PQ Bus): }\Delta\vec x^{(k)}='
                r'\begin{bmatrix}\Delta\delta_2^{(k)}\\[2pt]\Delta|V_2|^{(k)}\end{bmatrix}.',
        pvActive
            ? r'\textbf{Jacobian (For PV Bus): }\mathbf{J}^{(k)}='
                r'\begin{bmatrix}\dfrac{\partial p_2}{\partial\delta_2}\end{bmatrix}^{(k)}.'
            : r'\textbf{Jacobian (For PQ Bus): }\mathbf{J}^{(k)}='
                r'\begin{bmatrix}'
                r'\dfrac{\partial p_2}{\partial\delta_2} & \dfrac{\partial p_2}{\partial|V_2|}\\[6pt]'
                r'\dfrac{\partial q_2}{\partial\delta_2} & \dfrac{\partial q_2}{\partial|V_2|}'
                r'\end{bmatrix}^{(k)}.',
        r'',
        r'\textbf{Power Mismatch equation: }\Delta\vec u^{(k)}=\mathbf{J}^{(k)}\Delta\vec x^{(k)}.',
        r'\textbf{Solve for updates: }\Delta\vec x^{(k)}=(\mathbf{J}^{(k)})^{-1}\Delta\vec u^{(k)}.',
        r'',
        r'\textbf{Final state update: }\vec x^{(k+1)}=\vec x^{(k)}+\Delta\vec x^{(k)}.',
        r'\color{red}{\textbf{End Goal: each iteration finds the updated }\Delta\delta_2^{(k)}\textbf{ and }\Delta|V_2|^{(k)}.}',
        r'\color{red}{\textbf{Apply the update (index notation):}}',
        r'\delta_2^{(k+1)}=\delta_2^{(k)}+\Delta\delta_2^{(k)}.',
        pvActive
            ? r'|V_2^{(k+1)}|=|V_2|_{\text{spec}}\ (\text{PV fixes magnitude}).'
            : r'|V_2^{(k+1)}|=|V_2^{(k)}|+\Delta|V_2|^{(k)}.',
        r'\color{red}{\Delta\delta_2^{(k)}\text{ is in radians }\Rightarrow\ \Delta\delta_2^{(k)}(^\circ)=\Delta\delta_2^{(k)}(\text{rad})\times\dfrac{180}{\pi}.}',
        r'',
        r'\textbf{Stopping all iterations when: }|\Delta x|_{\max}=\max(|\Delta\delta_2|,\ |\Delta|V_2||)\ <\ \text{tol}.',
      ], size: 16),
    ],
  ),
),

const SizedBox(height: 14),

Text(
  'Workings for Iteration 1 (k = 0) — follow Steps 1) to 5)',
  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
),
const SizedBox(height: 10),

warnBox(
  Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      mLeft([
        r'\color{red}{\textbf{Step 1) Get required values from }\mathbf{Y}_{bus}}',
        r'|Y_{21}|=' + f6(y21mag) + r',\ \gamma_{21}=' + f6(g21deg) + r'^\circ.',
        r'|Y_{22}|=' + f6(y22mag) + r',\ \gamma_{22}=' + f6(g22deg) + r'^\circ.',
        r'\text{Also for this iteration: }|V_1|=' + f6(V1mag) + r',\ \delta_1=' + f6(d1deg) + r'^\circ.',
        r'',
        r'\textbf{Given at }k=0\textbf{:}',
        r'\color{red}{|V_2^{(0)}|}=' + f6(V20_used) + r',\ \color{red}{\delta_2^{(0)}}=' + f6(d20deg_used) + r'^\circ.',
        r'P_{2,\text{spec}}=' + f6(r.P2spec) + (pvActive ? r'\ (\text{PV})' : r'\ (\text{PQ})') + r'.',
        pvActive
            ? r'\text{PV: }Q_{2,\text{spec}}\text{ not used (we solve only }\Delta P\text{).}'
            : r'Q_{2,\text{spec}}=' + f6(Q2specUsed) + (dropped ? r'\ (\text{PV dropped}\rightarrow\text{PQ})' : r'') + r'.',
      ], size: 16),

      const SizedBox(height: 12),

      mLeft([
        r'\color{red}{\textbf{Step 2) Use slack }V_1\textbf{ and evaluate }p_2^{(0)},q_2^{(0)}}',
        r'',
        r'\textbf{Start from the 2-bus power equations at bus 2:}',
        r'p_2=|Y_{21}||V_1||V_2|\cos(\delta_2-\delta_1-\gamma_{21})+|Y_{22}||V_2|^2\cos(\gamma_{22}).',
        r'q_2=|Y_{21}||V_1||V_2|\sin(\delta_2-\delta_1-\gamma_{21})-|Y_{22}||V_2|^2\sin(\gamma_{22}).',
        r'',
        r'\textbf{Now Compute the Angle term:}',
        r'\delta_2^{(0)}-\delta_1-\gamma_{21}'
            r'=' + f6(d20deg_used) + r'^\circ'
            r'-' + f6(d1deg) + r'^\circ'
            r'-' + f6(g21deg) + r'^\circ'
            r'=' + f6(theta0deg) + r'^\circ.',
        r'\cos(\delta_2^{(0)}-\delta_1-\gamma_{21})=' + f6(cosT0) + r',\;'
            r'\sin(\delta_2^{(0)}-\delta_1-\gamma_{21})=' + f6(sinT0) + r'.',
        r'',
        r'\textbf{Now evaluate at }k=0\textbf{: }|V_2^{(0)}|=' + f6(V20_used) + r',\ \delta_2^{(0)}=' + f6(d20deg_used) + r'^\circ.',
        r'',
        r'\textbf{Compute }p_2^{(0)}',
        r'p_2^{(0)}=|Y_{21}||V_1||V_2^{(0)}|\cos(\delta_2^{(0)}-\delta_1-\gamma_{21})+|Y_{22}||V_2^{(0)}|^2\cos(\gamma_{22}).',
        r'='
            + f6(y21mag) + r'(' + f6(V1mag) + r')(' + f6(V20_used) + r')(' + f6(cosT0) + r')'
            + r'+' + f6(y22mag) + r'(' + f6(V20_used * V20_used) + r')(\cos(' + f6(g22deg) + r'^\circ)).',
        r'\Rightarrow\ p_2^{(0)}=' + f6(p20) + r'.',
        r'',
        r'\textbf{Compute }q_2^{(0)}',
        r'q_2^{(0)}=|Y_{21}||V_1||V_2^{(0)}|\sin(\delta_2^{(0)}-\delta_1-\gamma_{21})-|Y_{22}||V_2^{(0)}|^2\sin(\gamma_{22}).',
        r'='
            + f6(y21mag) + r'(' + f6(V1mag) + r')(' + f6(V20_used) + r')(' + f6(sinT0) + r')'
            + r'-' + f6(y22mag) + r'(' + f6(V20_used * V20_used) + r')(\sin(' + f6(g22deg) + r'^\circ)).',
        r'\Rightarrow\ q_2^{(0)}=' + f6(q20) + r'.',
      ], size: 16),

      const SizedBox(height: 12),

      mLeft([
        r'\color{red}{\textbf{Step 3) Form the mismatch vector }\Delta\vec u^{(0)}}',
        r'\Delta P_2^{(0)}=P_{2,\text{spec}}-p_2^{(0)}=' + f6(r.P2spec) + r'-' + f6(p20) + r'=' + f6(dP0) + r'.',
        pvActive
            ? r'\Delta Q_2^{(0)}\text{ is not used in PV mode.}'
            : r'\Delta Q_2^{(0)}=Q_{2,\text{spec}}-q_2^{(0)}=' + f6(Q2specUsed) + r'-' + f6(q20) + r'=' + f6(dQ0) + r'.',
        pvActive
            ? r'\Rightarrow\ \Delta\vec u^{(0)}=\begin{bmatrix}\Delta P_2^{(0)}\end{bmatrix}=\begin{bmatrix}' + f6(dP0) + r'\end{bmatrix}.'
            : r'\Rightarrow\ \Delta\vec u^{(0)}=\begin{bmatrix}\Delta P_2^{(0)}\\[2pt]\Delta Q_2^{(0)}\end{bmatrix}=\begin{bmatrix}' + f6(dP0) + r'\\[2pt]' + f6(dQ0) + r'\end{bmatrix}.',
      ], size: 16),

      const SizedBox(height: 14),

  // Step 4) differentiation + substitution 
  mLeft([
    r'\color{red}{\textbf{Step 4) Differentiate to form the Jacobian (show working)}}',
    r'\textbf{Start from (2-bus, polar):}',
    r'p_2=|Y_{21}||V_1||V_2|\cos(\delta_2-\delta_1-\gamma_{21})+|Y_{22}||V_2|^2\cos(\gamma_{22}).',
    r'q_2=|Y_{21}||V_1||V_2|\sin(\delta_2-\delta_1-\gamma_{21})-|Y_{22}||V_2|^2\sin(\gamma_{22}).',
    r'',
    r'\textbf{(a) }\ \dfrac{\partial p_2}{\partial \delta_2}\ \textbf{(chain rule)}',
    r'\dfrac{\partial}{\partial \delta_2}\Big[\cos(\delta_2-\delta_1-\gamma_{21})\Big]'
    r'=-\sin(\delta_2-\delta_1-\gamma_{21})\cdot \dfrac{\partial(\delta_2-\delta_1-\gamma_{21})}{\partial \delta_2}.',
    r'\textbf{Where}\ \dfrac{\partial(\delta_2-\delta_1-\gamma_{21})}{\partial \delta_2}=1.',
    r'\Rightarrow\ \boxed{\frac{\partial p_2}{\partial \delta_2}=-|Y_{21}||V_1||V_2|\sin(\delta_2-\delta_1-\gamma_{21})}.',
    r'',
    r'\textbf{(b) }\ \dfrac{\partial p_2}{\partial |V_2|}\ \textbf{(product + power rule)}',
    r'\dfrac{\partial}{\partial |V_2|}\Big(|Y_{21}||V_1||V_2|\cos(\delta_2-\delta_1-\gamma_{21})\Big)'
    r'=|Y_{21}||V_1|\cos(\delta_2-\delta_1-\gamma_{21})\quad(\text{angle term is constant w.r.t. }|V_2|).',
    r'\dfrac{\partial}{\partial |V_2|}\Big(|Y_{22}||V_2|^2\cos(\gamma_{22})\Big)'
    r'=|Y_{22}|\cos(\gamma_{22})\cdot 2|V_2|.',
    r'\Rightarrow\ \boxed{\frac{\partial p_2}{\partial |V_2|}=|Y_{21}||V_1|\cos(\delta_2-\delta_1-\gamma_{21})+2|Y_{22}||V_2|\cos(\gamma_{22})}.',
    r'',
    r'\textbf{(c) }\ \dfrac{\partial q_2}{\partial \delta_2}\ \textbf{(chain rule)}',
    r'\dfrac{\partial}{\partial \delta_2}\Big[\sin(\delta_2-\delta_1-\gamma_{21})\Big]'
    r'=\cos(\delta_2-\delta_1-\gamma_{21})\cdot \dfrac{\partial(\delta_2-\delta_1-\gamma_{21})}{\partial \delta_2}.',
    r'\textbf{Where}\ \dfrac{\partial(\delta_2-\delta_1-\gamma_{21})}{\partial \delta_2}=1.',
    r'\Rightarrow\ \boxed{\frac{\partial q_2}{\partial \delta_2}=|Y_{21}||V_1||V_2|\cos(\delta_2-\delta_1-\gamma_{21})}.',
    r'',
    r'\textbf{(d) }\ \dfrac{\partial q_2}{\partial |V_2|}\ \textbf{(product + power rule)}',
    r'\dfrac{\partial}{\partial |V_2|}\Big(|Y_{21}||V_1||V_2|\sin(\delta_2-\delta_1-\gamma_{21})\Big)'
    r'=|Y_{21}||V_1|\sin(\delta_2-\delta_1-\gamma_{21}).',
    r'\dfrac{\partial}{\partial |V_2|}\Big(-|Y_{22}||V_2|^2\sin(\gamma_{22})\Big)'
    r'=-|Y_{22}|\sin(\gamma_{22})\cdot 2|V_2|.',
    r'\Rightarrow\ \boxed{\frac{\partial q_2}{\partial |V_2|}=|Y_{21}||V_1|\sin(\delta_2-\delta_1-\gamma_{21})-2|Y_{22}||V_2|\sin(\gamma_{22})}.',
  ], size: 16),

  const SizedBox(height: 12),

  // substitution 
  mLeft([
    r'\textbf{Now substitute YOUR }k=0\textbf{ values into these derivatives:}',
    r'\text{Use }|Y_{21}|=' + f6(y21mag) + r',\ |Y_{22}|=' + f6(y22mag) + r',\ |V_1|=' + f6(V1mag) + r',\ |V_2^{(0)}|=' + f6(V20_used) + r'.',
    r'\text{Use }\delta_2^{(0)}=' + f6(d20deg_used) + r'^\circ,\ \delta_1=' + f6(d1deg) + r'^\circ,\ \gamma_{21}=' + f6(g21deg) + r'^\circ,\ \gamma_{22}=' + f6(g22deg) + r'^\circ.',
    r'',
    r'\left[\dfrac{\partial p_2}{\partial \delta_2}\right]^{(0)}'
    r'=-|Y_{21}||V_1||V_2^{(0)}|\sin(\delta_2^{(0)}-\delta_1-\gamma_{21})',
    r'=-(\,' + f6(y21mag) + r')(\,' + f6(V1mag) + r')(\,' + f6(V20_used) + r')'
    r'\sin(' + f6(d20deg_used) + r'^\circ-' + f6(d1deg) + r'^\circ-' + f6(g21deg) + r'^\circ)',
    r'=-(\,' + f6(y21mag) + r')(\,' + f6(V1mag) + r')(\,' + f6(V20_used) + r')(\,' + f6(sinT0) + r')'
    r'=' + f6(J11) + r'.',
    r'',
    r'\left[\dfrac{\partial p_2}{\partial |V_2|}\right]^{(0)}'
    r'=|Y_{21}||V_1|\cos(\delta_2^{(0)}-\delta_1-\gamma_{21})+2|Y_{22}||V_2^{(0)}|\cos(\gamma_{22})',
    r'=(\,' + f6(y21mag) + r')(\,' + f6(V1mag) + r')\cos(' + f6(d20deg_used) + r'^\circ-' + f6(d1deg) + r'^\circ-' + f6(g21deg) + r'^\circ)'
    r'+2(\,' + f6(y22mag) + r')(\,' + f6(V20_used) + r')\cos(' + f6(g22deg) + r'^\circ)',
    r'=(\,' + f6(y21mag) + r')(\,' + f6(V1mag) + r')(\,' + f6(cosT0) + r')'
    r'+2(\,' + f6(y22mag) + r')(\,' + f6(V20_used) + r')\cos(' + f6(g22deg) + r'^\circ)'
    r'=' + f6(J12) + r'.',
    r'',
    if (!pvActive)
      r'\left[\dfrac{\partial q_2}{\partial \delta_2}\right]^{(0)}'
      r'=|Y_{21}||V_1||V_2^{(0)}|\cos(\delta_2^{(0)}-\delta_1-\gamma_{21})'
      r'=(\,' + f6(y21mag) + r')(\,' + f6(V1mag) + r')(\,' + f6(V20_used) + r')(\,' + f6(cosT0) + r')=' + f6(J21) + r'.',
    if (!pvActive)
      r'\left[\dfrac{\partial q_2}{\partial |V_2|}\right]^{(0)}'
      r'=|Y_{21}||V_1|\sin(\delta_2^{(0)}-\delta_1-\gamma_{21})-2|Y_{22}||V_2^{(0)}|\sin(\gamma_{22})'
      r'\\'
      r'\phantom{\left[\dfrac{\partial q_2}{\partial |V_2|}\right]^{(0)}}'
      r'=(\,' + f6(y21mag) + r')(\,' + f6(V1mag) + r')(\,' + f6(sinT0) + r')'
      r'-2(\,' + f6(y22mag) + r')(\,' + f6(V20_used) + r')\sin(' + f6(g22deg) + r'^\circ)'
      r'=' + f6(J22) + r'.',
    r'',
    pvActive
        ? r'\Rightarrow\ J^{(0)}=\begin{bmatrix}' + f6(J11) + r'\end{bmatrix}\ (\text{PV: scalar}).'
        : r'\Rightarrow\ J^{(0)}=\begin{bmatrix}' + f6(J11) + r' & ' + f6(J12) + r'\\' + f6(J21) + r' & ' + f6(J22) + r'\end{bmatrix}.',
  ], size: 16),

  const SizedBox(height: 14),

  // Step 5) solve + Jacobian matrix + final update notes 
  mLeft([
    r'\color{red}{\textbf{Step 5) Solve for updates and apply the state update}}',
    pvActive
        ? r'\textbf{PV solve (scalar): }\Delta P_2^{(0)}=\left[\dfrac{\partial p_2}{\partial\delta_2}\right]^{(0)}\Delta\delta_2^{(0)}'
        : r'\textbf{PQ solve (matrix): }\Delta\vec x^{(0)}=(\mathbf{J}^{(0)})^{-1}\Delta\vec u^{(0)}.',
    r'',
    if (pvActive) ...[
      r'\textbf{What you are finding: }\Delta\vec x^{(0)}=\begin{bmatrix}\Delta\delta_2^{(0)}\end{bmatrix}.',
      r'\Delta\delta_2^{(0)}=\dfrac{\Delta P_2^{(0)}}{\left[\dfrac{\partial p_2}{\partial\delta_2}\right]^{(0)}}'
          r'=\dfrac{' + f6(dP0) + r'}{' + f6(J11) + r'}=' + f6(dDel0) + r'\ \text{rad}.',
      r'\color{red}{\Delta\delta_2^{(0)}(^\circ)=\Delta\delta_2^{(0)}(\text{rad})\times\dfrac{180}{\pi}}'
          r'=' + f6(dDel0) + r'\times\dfrac{180}{\pi}=' + f6(rad2deg(dDel0)) + r'^\circ.',
    ],
    if (!pvActive) ...[
      r'\textbf{What you are finding: }\Delta\vec x^{(0)}=\begin{bmatrix}\Delta\delta_2^{(0)}\\[2pt]\Delta|V_2|^{(0)}\end{bmatrix}.',
      r'\textbf{The exact calculator matrix multiplication is:}',
      r'\Delta\vec x^{(0)}=(\mathbf{J}^{(0)})^{-1}\Delta\vec u^{(0)}'
          r'=\left(\begin{bmatrix}' + f6(J11) + r' & ' + f6(J12) + r'\\' + f6(J21) + r' & ' + f6(J22) + r'\end{bmatrix}\right)^{-1}'
          r'\begin{bmatrix}' + f6(dP0) + r'\\[2pt]' + f6(dQ0) + r'\end{bmatrix}.',
      r'',
      r'\textbf{Compute the inverse:}',
      r'\det(\mathbf{J}^{(0)})=ad-bc'
          r'=(' + f6(J11) + r')(' + f6(J22) + r')-(' + f6(J12) + r')(' + f6(J21) + r')'
          r'=' + f6(detJ) + r'.',
      r'(\mathbf{J}^{(0)})^{-1}=\dfrac{1}{\det(\mathbf{J}^{(0)})}\begin{bmatrix}d & -b\\ -c & a\end{bmatrix}',
      r'=\dfrac{1}{' + f6(detJ) + r'}\begin{bmatrix}'
          + f6(J22) + r' & ' + f6(-J12) + r'\\'
          + f6(-J21) + r' & ' + f6(J11) + r'\end{bmatrix}',
      r'=\begin{bmatrix}'
          + f6(inv11) + r' & ' + f6(inv12) + r'\\'
          + f6(inv21) + r' & ' + f6(inv22) + r'\end{bmatrix}.',
      r'',
      r'\textbf{So the calculator step becomes: }'
          r'\Delta\vec x^{(0)}='
          r'\begin{bmatrix}\Delta\delta_2^{(0)}\\[2pt]\Delta|V_2|^{(0)}\end{bmatrix}'
          r'=\begin{bmatrix}'
          + f6(inv11) + r' & ' + f6(inv12) + r'\\'
          + f6(inv21) + r' & ' + f6(inv22) + r'\end{bmatrix}'
          r'\begin{bmatrix}' + f6(dP0) + r'\\[2pt]' + f6(dQ0) + r'\end{bmatrix}.',
      r'',
      r'\textbf{Now multiply (this is what you key into the calculator):}',
      r'\begin{bmatrix}\Delta\delta_2^{(0)}\\[2pt]\Delta|V_2|^{(0)}\end{bmatrix}'
          r'=\begin{bmatrix}'
          + f6(inv11) + r' & ' + f6(inv12) + r'\\'
          + f6(inv21) + r' & ' + f6(inv22) + r'\end{bmatrix}'
          r'\begin{bmatrix}' + f6(dP0) + r'\\[2pt]' + f6(dQ0) + r'\end{bmatrix}.',
      r'',
      r'\Delta\delta_2^{(0)}=(' + f6(inv11) + r')(' + f6(dP0) + r')+(' + f6(inv12) + r')(' + f6(dQ0) + r')=' + f6(dDel0) + r'\ \text{rad}.',
      r'\Delta|V_2|^{(0)}=(' + f6(inv21) + r')(' + f6(dP0) + r')+(' + f6(inv22) + r')(' + f6(dQ0) + r')=' + f6(dV0) + r'.',
      r'',
      r'\color{red}{\Delta\delta_2^{(0)}(^\circ)=\Delta\delta_2^{(0)}(\text{rad})\times\dfrac{180}{\pi}}'
          r'=' + f6(dDel0) + r'\times\dfrac{180}{\pi}=' + f6(rad2deg(dDel0)) + r'^\circ.',
    ],
    r'',
    r'\textbf{Final state update (what you get after Iteration 1):}',
    r'\vec x^{(0)}=\begin{bmatrix}\delta_2^{(0)}\\[2pt]|V_2^{(0)}|\end{bmatrix},\ \ \vec x^{(1)}=\begin{bmatrix}\delta_2^{(1)}\\[2pt]|V_2^{(1)}|\end{bmatrix}'
        r'=\vec x^{(0)}+\Delta\vec x^{(0)}.',
    r'',
    r'\textbf{Apply the update (index notation):}',
    r'\delta_2^{(1)}=\delta_2^{(0)}+\Delta\delta_2^{(0)}\ \ '
        r'\color{red}\text{Remember!} {(\Delta\delta_2^{(0)}\text{ is originally in rad; need to convert to degrees: }\Delta\delta_2^{(0)}(^\circ)=\Delta\delta_2^{(0)}(\text{rad})\times\dfrac{180}{\pi})}.',
    pvActive
        ? r'|V_2^{(1)}|=|V_2|_{\text{spec}}\ (\text{PV fixes magnitude}).'
        : r'|V_2^{(1)}|=|V_2^{(0)}|+\Delta|V_2|^{(0)}.',
    r'',
    r'\textbf{So for the 1st iteration }k=0:',
    r'\delta_2^{(1)}=' + f6(d20deg_used) + r'^\circ+' + f6(rad2deg(dDel0)) + r'^\circ=' + f6(d21_next_deg) + r'^\circ.',
    pvActive
        ? r'|V_2^{(1)}|=|V_2|_{\text{spec}}=' + f6(r.V2spec) + r'.'
        : r'|V_2^{(1)}|=' + f6(V20_used) + r'+' + f6(dV0) + r'=' + f6(V21_next) + r'.',
    if (!pvActive)
    r'\Rightarrow\ \vec V_2^{(1)}=' + f6(V21_next) + r'\angle ' + f6(d21_next_deg) + r'^\circ.',
  ], size: 16),
],
),
),
],
);
},
),
),
);


// Step 5: Remaining iterations (until converge or k-times)
steps.add(
mkStep(
r.iterateUntilConverge
? 'Iterate until |V2| and δ2 converge (table)'
: 'Iterations (k-times)',
_nrIterTable(r),
),
);

// Step 6: Slack power  
steps.add(
mkStep(
'Slack bus real and reactive power',
Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
latexLeft([
r'\textbf{Goal: compute slack-bus injected complex power } \vec S_1.',
r'\textbf{Key formulas to take note:}',
r'\vec S_i=\vec S_{Gi}-\vec S_{Di}.',
r'\vec S_{Gi}=P_{Gi}+jQ_{Gi}.',
r'\vec S_{Di}=P_{Di}+jQ_{Di}.',
r'',
r'\textbf{Therefore for Bus 1 (slack):}',
r'\vec S_1=\vec S_{G1}-\vec S_{D1}=(P_{G1}-P_{D1})+j(Q_{G1}-Q_{D1}).',
r'\text{This }\vec S_1=P_1+jQ_1\text{ is the net injection at Bus 1.}',
r'',

r'\textbf{Step 1: compute slack current from row 1 of }\mathbf{\vec Y}_{\text{bus}}',
r'\vec I_1=\sum_{j=1}^{n}\vec Y_{1j}\vec V_j.',
r'\text{For 2-bus: }\ \vec I_1=\vec Y_{11}\vec V_1+\vec Y_{12}\vec V_2^{(\text{final})}.',
r'',
r'\textbf{Step 2: compute slack injected power}',
r'\vec S_1=\vec V_1\,\vec I_1^{*}\;=\;P_1+jQ_1.',
r'',
r'\textbf{Given (final converged voltages)}',
r'\vec V_1=' + show(r.V1) + r',\ \vec V_2^{(\text{final})}=' + show(r.V2final) + r'.',
r'\vec Y_{11}=' + show(r.Y11) + r',\ \vec Y_{12}=' + show(r.Y12) + r'.',
r'',

r'\textbf{Substitute values}',
r'1)\ \vec I_{11}=\vec Y_{11}\vec V_1'
r'=\big(' + rect(r.Y11) + r'\big)\big(' + rect(r.V1) + r'\big)'
r'=' + show(I11_term) + r'.',
r'2)\ \vec I_{12}=\vec Y_{12}\vec V_2^{(\text{final})}'
r'=\big(' + rect(r.Y12) + r'\big)\big(' + rect(r.V2final) + r'\big)'
r'=' + show(I12_term) + r'.',
r'3)\ \vec I_1=\vec I_{11}+\vec I_{12}=' + show(I1_sum) + r'.',
r'4)\ \vec I_1^{*}=' + show(I1_star) + r'.',
r'5)\ \vec S_1=\vec V_1\,\vec I_1^{*}'
r'=\big(' + rect(r.V1) + r'\big)\big(' + rect(I1_star) + r'\big)'
r'=' + show(S1_calc) + r'.',
r'',

r'\textbf{Extract real and reactive power}',
r'P_1=\mathrm{Re}(\vec S_1)=' + sig(P1pu) + r'\ \text{pu},\ '
r'Q_1=\mathrm{Im}(\vec S_1)=' + sig(Q1pu) + r'\ \text{pu}.',

r'\textbf{Convert to actual (using }S_{\text{base}}\textbf{)}',

r'S_{\text{base}}=' + sig(r.sBaseMVA) + r'\ \text{MVA}.',

r'P_1=' + sig(P1pu) + r'\times ' + sig(r.sBaseMVA) +
r'=' + sig(P1_MW) + r'\ \text{MW}.',

r'Q_1=' + sig(Q1pu) + r'\times ' + sig(r.sBaseMVA) +
r'=' + sig(Q1_Mvar) + r'\ \text{Mvar}.',
], size: 16.5),

const SizedBox(height: 10),

// Work backwards from S1 to find missing generator or load power at Bus 1 (if not given)
if (r.bus1Given == Bus1Given.sd1) ...[
softBox(
latexLeft([
r'\textbf{Exam Question gives }\vec S_{d1}\textbf{ and need to find }\vec S_{g1}\textbf{:}\\'
r'\textbf{ }\vec S_{d1}\ \textbf{given}',
r'',
r'\vec S_1=' + show(r.S1) + r'.',
r'\vec S_{d1}=' + show(r.Sd1_given) + r'.',
r'',
r'\text{Use }\vec S_1=\vec S_{g1}-\vec S_{d1}\Rightarrow \vec S_{g1}=\vec S_1+\vec S_{d1}.',
r'',
r'\vec S_{g1}'
r'=\big(' + rect(r.S1) + r'\big)+\big(' + rect(r.Sd1_given) + r'\big)',
r'\vec S_{g1}'
r'=' + show(r.Sg1_required_from_Sd1) + r'.',
], size: 16),
),
] else if (r.bus1Given == Bus1Given.sg1) ...[
softBox(
latexLeft([
r'\textbf{Exam Question gives }\vec S_{g1}\textbf{ and need to find }\vec S_{d1}\textbf{:}\\'
r'\textbf{ }\vec S_{g1}\ \textbf{given}',
r'',
r'\vec S_1=' + show(r.S1) + r'.',
r'\vec S_{g1}=' + show(r.Sg1_given) + r'.',
r'',
r'\text{Use }\vec S_1=\vec S_{g1}-\vec S_{d1}\Rightarrow \vec S_{d1}=\vec S_{g1}-\vec S_1.',
r'',
r'\vec S_{d1}'
r'=\big(' + rect(r.Sg1_given) + r'\big)-\big(' + rect(r.S1) + r'\big)',
r'\vec S_{d1}'
r'=' + show(r.Sd1_required_from_Sg1) + r'.',
], size: 16),
),
] else ...[
softBox(
latexLeft([
r'\textbf{Sometimes Exam would give }\vec S_{d1}\textbf{ or }\vec S_{g1}\textbf{ and ask for the other (work backwards):}',
r'\text{If }\vec S_{d1}\text{ is given: }\ \vec S_{g1}=\vec S_1+\vec S_{d1}.',
r'\text{If }\vec S_{g1}\text{ is given: }\ \vec S_{d1}=\vec S_{g1}-\vec S_1.',
], size: 16),
),
],
],
),
),
);

// Step 7: Line flows and losses 
steps.add(
mkStep(
'Line flows and line losses',
Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
latexLeft([
r'\textbf{Goal: compute branch currents and complex power flow at both ends of the line.}',
r'\text{We will compute }\ \vec I_{12}\ \text{(leaving Bus 1 into the line) and }\ \vec I_{21}\ \text{(leaving Bus 2 into the line).}',
r'',

r'\textbf{Branch current equations}',
r'\vec I_{12}=\underbrace{\vec y_{12}(\vec V_1-\vec V_2)}_{\text{series current}}'
r'+\underbrace{\vec y_p\vec V_1}_{\text{shunt current at Bus 1}},\quad'
r'\vec I_{21}=\underbrace{\vec y_{12}(\vec V_2-\vec V_1)}_{\text{series current}}'
r'+\underbrace{\vec y_p\vec V_2}_{\text{shunt current at Bus 2}}.',
r'',

r'\textbf{Substitute final values}',
r'\vec V_1=' + show(r.V1) + r',\quad \vec V_2^{(\text{final})}=' + show(r.V2final) + r'.',
r'\vec y_{12}=' + show(r.y12Series) + r',\quad \vec y_p=' + show(r.yShunt) + r'.',
r'',

// Compute I12 (Bus 1 → Bus 2)
r'\underline{\textbf{Compute }\vec I_{12}\textbf{ (Bus 1 }\rightarrow\textbf{ Bus 2)}}',
r'1)\ \Delta \vec V_{12}=\vec V_1-\vec V_2^{(\text{final})}'
r'=\big(' + rect(r.V1) + r'\big)-\big(' + rect(r.V2final) + r'\big)'
r'=' + rect(V1mV2) + r'=' + polar(V1mV2) + r'.',

r'2)\ \vec I_{12,\text{series}}=\vec y_{12}\Delta \vec V_{12}'
r'=\big(' + rect(r.y12Series) + r'\big)\big(' + rect(V1mV2) + r'\big)'
r'=' + rect(I12_series) + r'=' + polar(I12_series) + r'.',

r'3)\ \vec I_{12,\text{shunt}}=\vec y_p\vec V_1'
r'=\big(' + rect(r.yShunt) + r'\big)\big(' + rect(r.V1) + r'\big)'
r'=' + rect(I12_shunt) + r'=' + polar(I12_shunt) + r'.',

r'4)\ \vec I_{12}=\vec I_{12,\text{series}}+\vec I_{12,\text{shunt}}'
r'=\big(' + rect(I12_series) + r'\big)+\big(' + rect(I12_shunt) + r'\big)'
r'=' + show(I12_sum) + r'.',
r'',

// Compute I21 (Bus 2 → Bus 1)
r'\underline{\textbf{Compute }\vec I_{21}\textbf{ (Bus 2 }\rightarrow\textbf{ Bus 1)}}',
r'1)\ \Delta \vec V_{21}=\vec V_2^{(\text{final})}-\vec V_1'
r'=\big(' + rect(r.V2final) + r'\big)-\big(' + rect(r.V1) + r'\big)'
r'=' + rect(V2mV1) + r'=' + polar(V2mV1) + r'.',

r'2)\ \vec I_{21,\text{series}}=\vec y_{12}\Delta \vec V_{21}'
r'=\big(' + rect(r.y12Series) + r'\big)\big(' + rect(V2mV1) + r'\big)'
r'=' + rect(I21_series) + r'=' + polar(I21_series) + r'.',

r'3)\ \vec I_{21,\text{shunt}}=\vec y_p\vec V_2^{(\text{final})}'
r'=\big(' + rect(r.yShunt) + r'\big)\big(' + rect(r.V2final) + r'\big)'
r'=' + rect(I21_shunt) + r'=' + polar(I21_shunt) + r'.',

r'4)\ \vec I_{21}=\vec I_{21,\text{series}}+\vec I_{21,\text{shunt}}'
r'=\big(' + rect(I21_series) + r'\big)+\big(' + rect(I21_shunt) + r'\big)'
r'=' + show(I21_sum) + r'.',
r'',

r'\textbf{Complex power flow definition}',
r'\vec S=\vec V\,\vec I^{*}\quad \Rightarrow\quad'
r'\vec S_{12}=\vec V_1\vec I_{12}^{*},\ \ \vec S_{21}=\vec V_2^{(\text{final})}\vec I_{21}^{*}.',
r'\textbf{Line loss: }\ \vec S_{\text{loss},12}=\vec S_{12}+\vec S_{21}.',
r'',

r'\underline{\textbf{Compute sending/receiving end powers}}',
r'1)\ \vec I_{12}^{*}=' + show(I12_star) + r'.',
r'\qquad \vec S_{12}=\vec V_1\vec I_{12}^{*}'
r'=\big(' + rect(r.V1) + r'\big)\big(' + rect(I12_star) + r'\big)'
r'=' + show(S12_calc) + r'.',
r'',
r'2)\ \vec I_{21}^{*}=' + show(I21_star) + r'.',
r'\qquad \vec S_{21}=\vec V_2^{(\text{final})}\vec I_{21}^{*}'
r'=\big(' + rect(r.V2final) + r'\big)\big(' + rect(I21_star) + r'\big)'
r'=' + show(S21_calc) + r'.',
r'',

r'\underline{\textbf{Line losses (per line, power balance)}}',
r'\vec S_{\text{loss},12}=\vec S_{12}+\vec S_{21}=' + show(Sloss_calc) + r'.',
r'P_{\text{loss}}\ \text{per unit (pu)}=\mathrm{Re}(\vec S_{\text{loss},12})=' + sig(Sloss_calc.re) + r'.',
r'Q_{\text{loss}}\ \text{per unit (pu)}=\mathrm{Im}(\vec S_{\text{loss},12})=' + sig(Sloss_calc.im) + r'.',
r'P_{\text{loss,actual}}=P_{\text{loss per unit}}\;S_{\text{base}}=' +
sig(Sloss_calc.re * r.sBaseMVA) + r'\ \text{MW}.',
r'Q_{\text{loss,actual}}=Q_{\text{loss per unit}}\;S_{\text{base}}=' +
sig(Sloss_calc.im * r.sBaseMVA) + r'\ \text{Mvar}\quad (S_{\text{base}}=' + sig(r.sBaseMVA) + r'\ \text{MVA}).',
r'',

r'\textbf{Sanity check (connect to Slack step):}',
r'\text{In a 2-bus system with one branch, slack injection should match sending-end flow }'
r'(\vec S_1 \approx \vec S_{12})\text{ up to rounding.}',
], size: 16.5),
],
),
),
);

return _buildStepsUI(steps);
}

Widget _nrIterTable(NR2Result r) {
String s(double v, [int k = 6]) => sig(v, k);

Widget th(String latex, {double size = 13}) {
return Math.tex(
latex,
mathStyle: MathStyle.text,
textStyle: TextStyle(fontSize: size, fontWeight: FontWeight.w700),
);
}
double deg2rad(double d) => d * math.pi / 180.0;
double rad2deg(double x) => x * 180.0 / math.pi;
String f6(num x) => x.toDouble().toStringAsFixed(6);

final double y21mag = r.Y21.abs();
final double g21deg = r.Y21.angDeg();
final double y22mag = r.Y22.abs();
final double g22deg = r.Y22.angDeg();

final bool pvUser = (r.bus2Type == BusType.pv);
final bool dropped = r.droppedToPQ;
final bool pvActive = pvUser && !dropped;

final double V1mag = r.V1.abs();
final double d1deg = r.V1.angDeg();

final double V20_used = (pvUser && dropped) ? 1.0 : r.V20_user.abs();
final double d20deg_used = (pvUser && dropped) ? 0.0 : r.V20_user.angDeg();

final double Q2specUsed = pvActive
? 0.0
: (dropped ? (r.Q2fixedFromLimit ?? r.Q2spec_user) : r.Q2spec_user);

List<String> _nrWorkingsLinesForIteration({
required int iter, 
required int kPrev,
required double V2prev,
required double d2prevDeg,
}) {
// angle term at kPrev
final double thetaDeg = d2prevDeg - d1deg - g21deg;
final double cosT = math.cos(deg2rad(thetaDeg));
final double sinT = math.sin(deg2rad(thetaDeg));
final double cosG22 = math.cos(deg2rad(g22deg));
final double sinG22 = math.sin(deg2rad(g22deg));

// power at kPrev
final double p2 = (y21mag * V1mag * V2prev * cosT) +
(y22mag * (V2prev * V2prev) * cosG22);
final double q2 = (y21mag * V1mag * V2prev * sinT) -
(y22mag * (V2prev * V2prev) * sinG22);

final double dP = r.P2spec - p2;
final double dQ = pvActive ? 0.0 : (Q2specUsed - q2);

// Jacobian at kPrev
final double J11 = -y21mag * V1mag * V2prev * sinT;
final double J12 =
(y21mag * V1mag * cosT) + (2.0 * y22mag * V2prev * cosG22);
final double J21 = (y21mag * V1mag * V2prev * cosT);
final double J22 =
(y21mag * V1mag * sinT) - (2.0 * y22mag * V2prev * sinG22);

// Solve updates
double dDel = 0.0; // rad
double dV = 0.0;
double detJ = 0.0;
double inv11 = 0.0, inv12 = 0.0, inv21 = 0.0, inv22 = 0.0;

if (pvActive) {
dDel = (J11.abs() < 1e-14) ? 0.0 : (dP / J11);
dV = 0.0;
} else {
detJ = (J11 * J22) - (J12 * J21);
if (detJ.abs() < 1e-14) {
dDel = 0.0;
dV = 0.0;
} else {
inv11 = J22 / detJ;
inv12 = -J12 / detJ;
inv21 = -J21 / detJ;
inv22 = J11 / detJ;

dDel = inv11 * dP + inv12 * dQ;
dV = inv21 * dP + inv22 * dQ;
}
}

final double d2nextDeg = d2prevDeg + rad2deg(dDel);
final double V2next = pvActive ? r.V2spec : (V2prev + dV);
final lines = <String>[];

lines.add(
r'\color{red}{\textbf{Iteration ' +
iter.toString() +
r': }(k=' +
kPrev.toString() +
r'\rightarrow ' +
iter.toString() +
r')}',
);

lines.add(r'\textbf{Given (previous guess):}');
lines.add(
r'\delta_2^{(' +
kPrev.toString() +
r')}=' +
f6(d2prevDeg) +
r'^\circ,\quad |V_2^{(' +
kPrev.toString() +
r')}|=' +
f6(V2prev) +
r'.',
);

lines.add(r'');
lines.add(
r'\color{red}{\textbf{Step 1) Get required values from }\mathbf{Y}_{bus}}');
lines.add(r'|Y_{21}|=' +
f6(y21mag) +
r',\ \gamma_{21}=' +
f6(g21deg) +
r'^\circ.');
lines.add(r'|Y_{22}|=' +
f6(y22mag) +
r',\ \gamma_{22}=' +
f6(g22deg) +
r'^\circ.');
lines.add(
r'|V_1|=' + f6(V1mag) + r',\ \delta_1=' + f6(d1deg) + r'^\circ.');
lines.add(r'');

lines.add(r'\color{red}{\textbf{Step 2) Use slack }V_1\textbf{ and evaluate }p_2^{(' +
kPrev.toString() +
r')},q_2^{(' +
kPrev.toString() +
r')}}');
lines.add(r'\textbf{Angle term (write it fully):}');
lines.add(
r'\delta_2^{(' +
kPrev.toString() +
r')}-\delta_1-\gamma_{21}'
r'=' +
f6(d2prevDeg) +
r'^\circ-' +
f6(d1deg) +
r'^\circ-' +
f6(g21deg) +
r'^\circ=' +
f6(thetaDeg) +
r'^\circ.',
);
lines.add(r'\cos(' +
f6(thetaDeg) +
r'^\circ)=' +
f6(cosT) +
r',\ \sin(' +
f6(thetaDeg) +
r'^\circ)=' +
f6(sinT) +
r'.');
lines.add(r'');
lines.add(
r'p_2=|Y_{21}||V_1||V_2|\cos(\delta_2-\delta_1-\gamma_{21})+|Y_{22}||V_2|^2\cos(\gamma_{22}).');
lines.add(
r'q_2=|Y_{21}||V_1||V_2|\sin(\delta_2-\delta_1-\gamma_{21})-|Y_{22}||V_2|^2\sin(\gamma_{22}).');
lines.add(r'');
lines.add(r'\Rightarrow\ p_2^{(' +
kPrev.toString() +
r')}=' +
f6(p2) +
r',\quad q_2^{(' +
kPrev.toString() +
r')}=' +
f6(q2) +
r'.');
lines.add(r'');

lines.add(r'\color{red}{\textbf{Step 3) Form the mismatch vector }\Delta\vec u^{(' +
kPrev.toString() +
r')}}');
lines.add(r'\Delta P_2^{(' +
kPrev.toString() +
r')}=P_{2,\text{spec}}-p_2^{(' +
kPrev.toString() +
r')}=' +
f6(r.P2spec) +
r'-' +
f6(p2) +
r'=' +
f6(dP) +
r'.');
if (!pvActive) {
lines.add(r'\Delta Q_2^{(' +
kPrev.toString() +
r')}=Q_{2,\text{spec}}-q_2^{(' +
kPrev.toString() +
r')}=' +
f6(Q2specUsed) +
r'-' +
f6(q2) +
r'=' +
f6(dQ) +
r'.');
lines.add(r'\Rightarrow\ \Delta\vec u^{(' +
kPrev.toString() +
r')}=\begin{bmatrix}' +
f6(dP) +
r'\\[2pt]' +
f6(dQ) +
r'\end{bmatrix}.');
} else {
lines.add(r'\Rightarrow\ \Delta\vec u^{(' +
kPrev.toString() +
r')}=\begin{bmatrix}' +
f6(dP) +
r'\end{bmatrix}\ (\text{PV}).');
}
lines.add(r'');

// Step 4) Jacobian Matrix
lines.add(
r'\color{red}{\textbf{Step 4) Differentiate to form the Jacobian (show working)}}',
);

lines.add(r'\textbf{Start from (2-bus, polar):}');
lines.add(
r'p_2=|Y_{21}||V_1||V_2|\cos(\delta_2-\delta_1-\gamma_{21})+|Y_{22}||V_2|^2\cos(\gamma_{22}).');
lines.add(
r'q_2=|Y_{21}||V_1||V_2|\sin(\delta_2-\delta_1-\gamma_{21})-|Y_{22}||V_2|^2\sin(\gamma_{22}).');
lines.add(r'');

lines.add(r'\textbf{Final derivative forms:}');
lines.add(
r'(a)\ \boxed{\frac{\partial p_2}{\partial \delta_2}=-|Y_{21}||V_1||V_2|\sin(\delta_2-\delta_1-\gamma_{21})}.');
lines.add(
r'(b)\ \boxed{\frac{\partial p_2}{\partial |V_2|}=|Y_{21}||V_1|\cos(\delta_2-\delta_1-\gamma_{21})+2|Y_{22}||V_2|\cos(\gamma_{22})}.');
if (!pvActive) {
lines.add(
r'(c)\ \boxed{\frac{\partial q_2}{\partial \delta_2}=|Y_{21}||V_1||V_2|\cos(\delta_2-\delta_1-\gamma_{21})}.');
lines.add(
r'(d)\ \boxed{\frac{\partial q_2}{\partial |V_2|}=|Y_{21}||V_1|\sin(\delta_2-\delta_1-\gamma_{21})-2|Y_{22}||V_2|\sin(\gamma_{22})}.');
}
lines.add(r'');

lines.add(r'\textbf{Now substitute YOUR }k=' +
kPrev.toString() +
r'\textbf{ values:}');
lines.add(r'|Y_{21}|=' +
f6(y21mag) +
r',\ |Y_{22}|=' +
f6(y22mag) +
r',\ |V_1|=' +
f6(V1mag) +
r',\ |V_2^{(' +
kPrev.toString() +
r')}|=' +
f6(V2prev) +
r'.');
lines.add(r'\delta_2^{(' +
kPrev.toString() +
r')}=' +
f6(d2prevDeg) +
r'^\circ,\ \delta_1=' +
f6(d1deg) +
r'^\circ,\ \gamma_{21}=' +
f6(g21deg) +
r'^\circ,\ \gamma_{22}=' +
f6(g22deg) +
r'^\circ.');
lines.add(r'\text{Angle term: }\ (\delta_2^{(' +
kPrev.toString() +
r')}-\delta_1-\gamma_{21})=' +
f6(thetaDeg) +
r'^\circ.');
lines.add(
r'\cos(' +
f6(thetaDeg) +
r'^\circ)=' +
f6(cosT) +
r',\ \sin(' +
f6(thetaDeg) +
r'^\circ)=' +
f6(sinT) +
r'.');
lines.add(r'');

lines.add(r'\left[\frac{\partial p_2}{\partial \delta_2}\right]^{(' +
kPrev.toString() +
r')}'
r'=-|Y_{21}||V_1||V_2^{(' +
kPrev.toString() +
r')}|\sin(\delta_2^{(' +
kPrev.toString() +
r')}-\delta_1-\gamma_{21})');
lines.add(r'=-(\,' +
f6(y21mag) +
r')(\,' +
f6(V1mag) +
r')(\,' +
f6(V2prev) +
r')(\,' +
f6(sinT) +
r')'
r'=' +
f6(J11) +
r'.');

lines.add(r'');

lines.add(r'\left[\frac{\partial p_2}{\partial |V_2|}\right]^{(' +
kPrev.toString() +
r')}'
r'=|Y_{21}||V_1|\cos(\delta_2^{(' +
kPrev.toString() +
r')}-\delta_1-\gamma_{21})+2|Y_{22}||V_2^{(' +
kPrev.toString() +
r')}|\cos(\gamma_{22})');
lines.add(r'=(\,' +
f6(y21mag) +
r')(\,' +
f6(V1mag) +
r')(\,' +
f6(cosT) +
r')+2(\,' +
f6(y22mag) +
r')(\,' +
f6(V2prev) +
r')\cos(' +
f6(g22deg) +
r'^\circ)');
lines.add(r'=' + f6(J12) + r'.');

if (!pvActive) {
lines.add(r'');

lines.add(r'\left[\frac{\partial q_2}{\partial \delta_2}\right]^{(' +
kPrev.toString() +
r')}'
r'=|Y_{21}||V_1||V_2^{(' +
kPrev.toString() +
r')}|\cos(\delta_2^{(' +
kPrev.toString() +
r')}-\delta_1-\gamma_{21})');
lines.add(r'=(\,' +
f6(y21mag) +
r')(\,' +
f6(V1mag) +
r')(\,' +
f6(V2prev) +
r')(\,' +
f6(cosT) +
r')'
r'=' +
f6(J21) +
r'.');

lines.add(r'');

lines.add(r'\left[\frac{\partial q_2}{\partial |V_2|}\right]^{(' +
kPrev.toString() +
r')}'
r'=|Y_{21}||V_1|\sin(\delta_2^{(' +
kPrev.toString() +
r')}-\delta_1-\gamma_{21})-2|Y_{22}||V_2^{(' +
kPrev.toString() +
r')}|\sin(\gamma_{22})');
lines.add(r'=(\,' +
f6(y21mag) +
r')(\,' +
f6(V1mag) +
r')(\,' +
f6(sinT) +
r')-2(\,' +
f6(y22mag) +
r')(\,' +
f6(V2prev) +
r')\sin(' +
f6(g22deg) +
r'^\circ)');
lines.add(r'=' + f6(J22) + r'.');

lines.add(r'');
lines.add(r'\Rightarrow\ \mathbf{J}^{(' +
kPrev.toString() +
r')}='
r'\begin{bmatrix}' +
f6(J11) +
r' & ' +
f6(J12) +
r'\\' +
f6(J21) +
r' & ' +
f6(J22) +
r'\end{bmatrix}.');
} else {
lines.add(r'');
lines.add(r'\Rightarrow\ \mathbf{J}^{(' +
kPrev.toString() +
r')}=\begin{bmatrix}' +
f6(J11) +
r'\end{bmatrix}\ (\text{PV: scalar}).');
}

lines.add(r'');

// Step 5) Solve for updates then apply the state update
lines.add(
r'\color{red}{\textbf{Step 5) Solve for updates and apply the state update}}');

if (!pvActive) {
lines.add(r'\Delta\vec x^{(' +
kPrev.toString() +
r')}=(\mathbf{J}^{(' +
kPrev.toString() +
r')})^{-1}\Delta\vec u^{(' +
kPrev.toString() +
r')}.');
lines.add(r'\Delta\vec x^{(' +
kPrev.toString() +
r')}=\begin{bmatrix}\Delta\delta_2^{(' +
kPrev.toString() +
r')}\\[2pt]\Delta|V_2|^{(' +
kPrev.toString() +
r')}\end{bmatrix}.');
lines.add(r'');

lines.add(r'\textbf{Compute the inverse:}');
lines.add(r'\det(\mathbf{J}^{(' +
kPrev.toString() +
r')})=ad-bc'
r'=(' +
f6(J11) +
r')(' +
f6(J22) +
r')-(' +
f6(J12) +
r')(' +
f6(J21) +
r')'
r'=' +
f6(detJ) +
r'.');
lines.add(r'(\mathbf{J}^{(' +
kPrev.toString() +
r')})^{-1}=\dfrac{1}{\det(\mathbf{J}^{(' +
kPrev.toString() +
r')})}\begin{bmatrix}d & -b\\ -c & a\end{bmatrix}.');
lines.add(r'=\dfrac{1}{' +
f6(detJ) +
r'}\begin{bmatrix}' +
f6(J22) +
r' & ' +
f6(-J12) +
r'\\' +
f6(-J21) +
r' & ' +
f6(J11) +
r'\end{bmatrix}'
r'=\begin{bmatrix}' +
f6(inv11) +
r' & ' +
f6(inv12) +
r'\\' +
f6(inv21) +
r' & ' +
f6(inv22) +
r'\end{bmatrix}.');
lines.add(r'');

lines.add(r'\textbf{So the calculator step becomes:}');
lines.add(r'\begin{bmatrix}\Delta\delta_2^{(' +
kPrev.toString() +
r')}\\[2pt]\Delta|V_2|^{(' +
kPrev.toString() +
r')}\end{bmatrix}'
r'=\begin{bmatrix}' +
f6(inv11) +
r' & ' +
f6(inv12) +
r'\\' +
f6(inv21) +
r' & ' +
f6(inv22) +
r'\end{bmatrix}'
r'\begin{bmatrix}' +
f6(dP) +
r'\\[2pt]' +
f6(dQ) +
r'\end{bmatrix}.');
lines.add(r'');

lines.add(r'\textbf{Now multiply (row-by-row):}');
lines.add(r'\Delta\delta_2^{(' +
kPrev.toString() +
r')}=(' +
f6(inv11) +
r')(' +
f6(dP) +
r')+(' +
f6(inv12) +
r')(' +
f6(dQ) +
r')'
r'=' +
f6(dDel) +
r'\ \text{rad}.');
lines.add(r'\Delta|V_2|^{(' +
kPrev.toString() +
r')}=(' +
f6(inv21) +
r')(' +
f6(dP) +
r')+(' +
f6(inv22) +
r')(' +
f6(dQ) +
r')'
r'=' +
f6(dV) +
r'.');

lines.add(r'');

lines.add(r'\color{red}{\Delta\delta_2^{(' +
kPrev.toString() +
r')}(^\circ)=\Delta\delta_2^{(' +
kPrev.toString() +
r')}(\text{rad})\times\dfrac{180}{\pi}}'
r'=' +
f6(dDel) +
r'\times\dfrac{180}{\pi}=' +
f6(rad2deg(dDel)) +
r'^\circ.');

lines.add(r'');

lines.add(r'\textbf{Apply update:}');
lines.add(r'\delta_2^{(' +
iter.toString() +
r')}=\delta_2^{(' +
kPrev.toString() +
r')}+\Delta\delta_2^{(' +
kPrev.toString() +
r')}'
r'\ \ \color{red}{(\Delta\delta\ \text{in rad; convert to degrees with } \times\dfrac{180}{\pi}).}');
lines.add(r'|V_2^{(' +
iter.toString() +
r')}|=|V_2^{(' +
kPrev.toString() +
r')}|+\Delta|V_2|^{(' +
kPrev.toString() +
r')}.');
lines.add(r'');

lines.add(r'\Rightarrow\ \delta_2^{(' +
iter.toString() +
r')}=' +
f6(d2prevDeg) +
r'^\circ+' +
f6(rad2deg(dDel)) +
r'^\circ=' +
f6(d2nextDeg) +
r'^\circ.');
lines.add(r'\Rightarrow\ |V_2^{(' +
iter.toString() +
r')}|=' +
f6(V2prev) +
r'+' +
f6(dV) +
r'=' +
f6(V2next) +
r'.');
lines.add(r'\Rightarrow\ \vec V_2^{(' +
iter.toString() +
r')}\approx ' +
f6(V2next) +
r'\angle ' +
f6(d2nextDeg) +
r'^\circ.');
} else {
lines.add(r'\Delta P_2^{(' +
kPrev.toString() +
r')}=\left[\frac{\partial p_2}{\partial\delta_2}\right]^{(' +
kPrev.toString() +
r')}\Delta\delta_2^{(' +
kPrev.toString() +
r')}.');
lines.add(r'\Delta\delta_2^{(' +
kPrev.toString() +
r')}=\dfrac{\Delta P_2^{(' +
kPrev.toString() +
r')}}{\left[\frac{\partial p_2}{\partial\delta_2}\right]^{(' +
kPrev.toString() +
r')}}'
r'=\dfrac{' +
f6(dP) +
r'}{' +
f6(J11) +
r'}=' +
f6(dDel) +
r'\ \text{rad}.');
lines.add(r'\color{red}{\Delta\delta_2^{(' +
kPrev.toString() +
r')}(^\circ)=\Delta\delta_2^{(' +
kPrev.toString() +
r')}(\text{rad})\times\dfrac{180}{\pi}}'
r'=' +
f6(dDel) +
r'\times\dfrac{180}{\pi}=' +
f6(rad2deg(dDel)) +
r'^\circ.');
lines.add(r'\Rightarrow\ \delta_2^{(' +
iter.toString() +
r')}=' +
f6(d2nextDeg) +
r'^\circ.');
lines.add(r'|V_2^{(' +
iter.toString() +
r')}|=|V_2|_{\text{spec}}=' +
f6(r.V2spec) +
r'.');
}

return lines;
}

final kRan = r.rows.length;

Widget thHdr(String latex, {double w = 92, double size = 15}) {
return SizedBox(
width: w,
child: Center(
child: FittedBox(
fit: BoxFit.scaleDown,
child: th(latex, size: size),
),
),
);
}

// Build table rows
final List<DataRow> tableRows = [
// Iteration 0 (initial guess / flat start)
DataRow(cells: [
const DataCell(Text('0')),
DataCell(Text(s(d20deg_used, 6))), // δ2^(0) deg
DataCell(Text(s(V20_used, 6))),    // |V2^(0)|
const DataCell(Text('-')),         // Δδ2 deg
const DataCell(Text('-')),         // Δ|V2|
const DataCell(Text('-')),         // ΔP2
const DataCell(Text('-')),         // ΔQ2
]),


...r.rows.map((rr) {
final d2Deg = rr.d2Rad * 180.0 / math.pi; // state angle (deg) for that row
final dDelDeg = rr.dDelta * 180.0 / math.pi; // update angle (deg) for that row
return DataRow(cells: [
DataCell(Text(rr.k.toString())),
DataCell(Text(s(d2Deg, 6))),
DataCell(Text(s(rr.v2Mag, 6))),
DataCell(Text(s(dDelDeg, 6))),
DataCell(Text(s(rr.dV, 6))),
DataCell(Text(s(rr.misP, 6))),
DataCell(Text(s(rr.misQ, 6))),
]);
}).toList(),
];

return Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
const SizedBox(height: 6),
Text(
r.converged
? 'Converged in ${r.rows.length} iteration(s).'
: (r.iterateUntilConverge
? 'Stopped at ${r.rows.length} iteration(s) (max).'
: 'Fixed-iteration mode: ran $kRan iteration(s).'),
style: TextStyle(
fontWeight: FontWeight.w600,
color: r.converged ? Colors.green[800] : Colors.orange[800],
),
),
if (r.droppedToPQ)
Padding(
padding: const EdgeInsets.only(top: 6),
child: Text(
'Note: PV → PQ due to Q-limit violation.',
style: TextStyle(
fontWeight: FontWeight.w600,
color: Colors.orange[800],
),
),
),
const SizedBox(height: 10),

// table
SingleChildScrollView(
scrollDirection: Axis.horizontal,
child: DataTable(
columns: [
DataColumn(
label: SizedBox(
width: 70,
child: Center(
  child: Text('Iteration',
      style: TextStyle(fontWeight: FontWeight.w700)),
),
),
),
DataColumn(label: thHdr(r'\delta_2\ (\deg)', w: 90)),
DataColumn(label: thHdr(r'|V_2|\ (\text{pu})', w: 95)),
DataColumn(label: thHdr(r'\Delta\delta_2\ (\deg)', w: 100)),
DataColumn(label: thHdr(r'\Delta|V_2|\ (\text{pu})', w: 110)),
DataColumn(label: thHdr(r'\Delta P_2', w: 80)),
DataColumn(label: thHdr(r'\Delta Q_2', w: 80)),
],

rows: tableRows,
),
),

const SizedBox(height: 14),

if (!r.iterateUntilConverge) ...[
...r.rows.map((rr) {

final int iter = rr.k; 
final int kPrev = iter - 1;

double V2prev;
double d2prevDeg;

if (iter == 1) {
V2prev = V20_used;
d2prevDeg = d20deg_used;
} else {
final prevRow = r.rows[iter - 2]; 
V2prev = prevRow.v2Mag;
d2prevDeg = rad2deg(prevRow.d2Rad);
}

final lines = _nrWorkingsLinesForIteration(
iter: iter,
kPrev: kPrev,
V2prev: V2prev,
d2prevDeg: d2prevDeg,
);

return Padding(
padding: const EdgeInsets.only(bottom: 10),
child: warnBox(
Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
  latexLeft(lines, size: 16.2),
],
),
),
);
}).toList(),
],

const SizedBox(height: 10),
Builder(builder: (context) {
final double finalDelta2Deg = r.rows.isEmpty
? d20deg_used
: (r.rows.last.d2Rad * 180.0 / math.pi);

final double finalV2Mag = r.rows.isEmpty ? V20_used : r.rows.last.v2Mag;

return latexLeft(
[
r'\textbf{Final } \vec V_2 \approx ' +
s(r.V2final.re, 5) +
(r.V2final.im >= 0 ? r' + j' : r' - j') +
s(r.V2final.im.abs(), 5) +
r'\quad (' +
s(finalV2Mag, 5) +
r'\angle ' +
s(finalDelta2Deg, 5) +
r'^\circ).',
],
size: 16.2,
);
}),
],
);
}
}
