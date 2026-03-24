// lib/screens/solver_screen_gauss_seidel_3bus.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_math_fork/flutter_math.dart';

import '../domain/complex.dart';
import '../domain/powerflow_model_gs3.dart';
import '../domain/powerflow_solver_gs3.dart';
import '../utils/format.dart';
import '../widgets/latex_blocks.dart';
import '../widgets/ui_helpers.dart';

class SolverScreenGS3Bus extends StatefulWidget {
const SolverScreenGS3Bus({super.key});
@override
State<SolverScreenGS3Bus> createState() => _SolverScreenGS3BusState();
}

class _SolverScreenGS3BusState extends State<SolverScreenGS3Bus> {
// Impendance Base + line data 
final _sBaseCtrl = TextEditingController(text: '100'); // MVA
final _vBaseCtrl = TextEditingController(text: '230'); // kV

final _r12Ctrl = TextEditingController(text: '0.02');
final _x12Ctrl = TextEditingController(text: '0.04');
final _b12Ctrl = TextEditingController(text: '0');

final _r13Ctrl = TextEditingController(text: '0.01');
final _x13Ctrl = TextEditingController(text: '0.03');
final _b13Ctrl = TextEditingController(text: '0');

final _r23Ctrl = TextEditingController(text: '0.0125');
final _x23Ctrl = TextEditingController(text: '0.025');
final _b23Ctrl = TextEditingController(text: '0');

bool _lineDataInPu = true;

// Direct Y-bus input mode 
bool _useDirectYbus = false;

final _y11ReCtrl = TextEditingController(text: '6.67');
final _y11ImCtrl = TextEditingController(text: '-19.89');
final _y12ReCtrl = TextEditingController(text: '-1.67');
final _y12ImCtrl = TextEditingController(text: '5.0');
final _y13ReCtrl = TextEditingController(text: '-5.0');
final _y13ImCtrl = TextEditingController(text: '15.0');
final _y22ReCtrl = TextEditingController(text: '4.17');
final _y22ImCtrl = TextEditingController(text: '-12.4');
final _y23ReCtrl = TextEditingController(text: '-2.5');
final _y23ImCtrl = TextEditingController(text: '7.5');
final _y33ReCtrl = TextEditingController(text: '7.5');
final _y33ImCtrl = TextEditingController(text: '-22.39');

// Bus types 
BusKind _bus1Type = BusKind.slack;
BusKind _bus2Type = BusKind.pq;
BusKind _bus3Type = BusKind.pq;

SlackGiven _slackGiven = SlackGiven.none;

// Bus 1
final _v1MagCtrl = TextEditingController(text: '1.05');
final _d1Ctrl = TextEditingController(text: '0');

final _pg1Ctrl = TextEditingController(text: '0');
final _qg1Ctrl = TextEditingController(text: '0');
final _pd1Ctrl = TextEditingController(text: '0');
final _qd1Ctrl = TextEditingController(text: '0');

final _q1MinCtrl = TextEditingController(text: '');
final _q1MaxCtrl = TextEditingController(text: '');

bool _bus1PowersInPu = true;

// Bus 2 
final _v2MagCtrl = TextEditingController(text: '1.0');
final _d2Ctrl = TextEditingController(text: '0');

final _pg2Ctrl = TextEditingController(text: '0');
final _qg2Ctrl = TextEditingController(text: '0');
final _pd2Ctrl = TextEditingController(text: '256.6');
final _qd2Ctrl = TextEditingController(text: '110.2');

final _q2MinCtrl = TextEditingController(text: '');
final _q2MaxCtrl = TextEditingController(text: '');

bool _bus2PowersInPu = false;

// Bus 3 
final _v3MagCtrl = TextEditingController(text: '1.0');
final _d3Ctrl = TextEditingController(text: '0');

final _pg3Ctrl = TextEditingController(text: '0');
final _qg3Ctrl = TextEditingController(text: '0');
final _pd3Ctrl = TextEditingController(text: '138.6');
final _qd3Ctrl = TextEditingController(text: '45.2');

final _q3MinCtrl = TextEditingController(text: '');
final _q3MaxCtrl = TextEditingController(text: '');

bool _bus3PowersInPu = false;

// Iteration settings 
final _tolCtrl = TextEditingController(text: '1e-4');
final _maxIterCtrl = TextEditingController(text: '50');
final _fixedIterCtrl = TextEditingController(text: '2');

bool iterate = true;

// PRESETS 
late final List<GS3Preset> _presets = gs3Presets;
GS3Preset? _selectedPreset;

void _applyPreset(GS3Preset p) {
setState(() {
_lineDataInPu = p.lineDataInPu;
_useDirectYbus = p.useDirectYbus;

_bus1PowersInPu = p.bus1PowersInPu;
_bus2PowersInPu = p.bus2PowersInPu;
_bus3PowersInPu = p.bus3PowersInPu;

iterate = p.iterate;
_fixedIterCtrl.text = p.fixedIterK;
_tolCtrl.text = p.tol;
_maxIterCtrl.text = p.maxIter;

_bus1Type = p.bus1Type;
_bus2Type = p.bus2Type;
_bus3Type = p.bus3Type;
_slackGiven = p.slackGiven;

_sBaseCtrl.text = p.sBase;
_vBaseCtrl.text = p.vBase;

_r12Ctrl.text = p.r12;
_x12Ctrl.text = p.x12;
_r13Ctrl.text = p.r13;
_x13Ctrl.text = p.x13;
_r23Ctrl.text = p.r23;
_x23Ctrl.text = p.x23;

_y11ReCtrl.text = p.y11Re;
_y11ImCtrl.text = p.y11Im;
_y12ReCtrl.text = p.y12Re;
_y12ImCtrl.text = p.y12Im;
_y13ReCtrl.text = p.y13Re;
_y13ImCtrl.text = p.y13Im;
_y22ReCtrl.text = p.y22Re;
_y22ImCtrl.text = p.y22Im;
_y23ReCtrl.text = p.y23Re;
_y23ImCtrl.text = p.y23Im;
_y33ReCtrl.text = p.y33Re;
_y33ImCtrl.text = p.y33Im;

_v1MagCtrl.text = p.v1Mag;
_d1Ctrl.text = p.d1;
_v2MagCtrl.text = p.v2Mag;
_d2Ctrl.text = p.d2;
_v3MagCtrl.text = p.v3Mag;
_d3Ctrl.text = p.d3;

_pg1Ctrl.text = p.pg1;
_qg1Ctrl.text = p.qg1;
_pd1Ctrl.text = p.pd1;
_qd1Ctrl.text = p.qd1;

_pg2Ctrl.text = p.pg2;
_qg2Ctrl.text = p.qg2;
_pd2Ctrl.text = p.pd2;
_qd2Ctrl.text = p.qd2;

_pg3Ctrl.text = p.pg3;
_qg3Ctrl.text = p.qg3;
_pd3Ctrl.text = p.pd3;
_qd3Ctrl.text = p.qd3;

_q1MinCtrl.text = p.q1Min;
_q1MaxCtrl.text = p.q1Max;
_q2MinCtrl.text = p.q2Min;
_q2MaxCtrl.text = p.q2Max;
_q3MinCtrl.text = p.q3Min;
_q3MaxCtrl.text = p.q3Max;

_error = null;
res = null;
_showAllWorkings = false;
_openStep = -1;
});
}

// Diagram helpers 
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

bool _showAllWorkings = false;
int _openStep = -1;

String? _error;
GS3Result? res;

TextStyle get _stepHeaderStyle => TextStyle(
fontSize: 18,
fontWeight: FontWeight.w800,
color: Colors.red[700],
);

// Parsing helpers 
double _p(TextEditingController c, double fallback) {
final t = c.text.trim();
if (t.isEmpty) return fallback;
return double.tryParse(t) ?? double.tryParse(t.toLowerCase().replaceAll('e', 'E')) ?? fallback;
}

double? _pNullable(TextEditingController c) {
final t = c.text.trim();
if (t.isEmpty) return null;
return double.tryParse(t) ?? double.tryParse(t.toLowerCase().replaceAll('e', 'E'));
}

int _pi(TextEditingController c, int fallback) {
final t = c.text.trim();
return int.tryParse(t) ?? fallback;
}

bool _anyEmpty() {
final all = <TextEditingController>[
_sBaseCtrl,
_vBaseCtrl,
_r12Ctrl,
_x12Ctrl,
_r13Ctrl,
_x13Ctrl,
_r23Ctrl,
_x23Ctrl,
_v1MagCtrl,
_d1Ctrl,
_pg1Ctrl,
_qg1Ctrl,
_pd1Ctrl,
_qd1Ctrl,
_v2MagCtrl,
_d2Ctrl,
_pg2Ctrl,
_qg2Ctrl,
_pd2Ctrl,
_qd2Ctrl,
_v3MagCtrl,
_d3Ctrl,
_pg3Ctrl,
_qg3Ctrl,
_pd3Ctrl,
_qd3Ctrl,
_tolCtrl,
_maxIterCtrl,
];
for (final c in all) {
if (c.text.trim().isEmpty) return true;
}
return false;
}

// Compute solver
void _compute() {
setState(() {
_error = null;
res = null;
_showAllWorkings = false;
_openStep = -1;
});

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
final r13 = _p(_r13Ctrl, 0.0);
final x13 = _p(_x13Ctrl, 0.0);
final r23 = _p(_r23Ctrl, 0.0);
final x23 = _p(_x23Ctrl, 0.0);

final v1Mag = _p(_v1MagCtrl, 1.0);
final d1Deg = _p(_d1Ctrl, 0.0);

final v2Mag = _p(_v2MagCtrl, 1.0);
final d2Deg = _p(_d2Ctrl, 0.0);

final v3Mag = _p(_v3MagCtrl, 1.0);
final d3Deg = _p(_d3Ctrl, 0.0);

final pg1 = _p(_pg1Ctrl, 0.0);
final qg1 = _p(_qg1Ctrl, 0.0);
final pd1 = _p(_pd1Ctrl, 0.0);
final qd1 = _p(_qd1Ctrl, 0.0);

final pg2 = _p(_pg2Ctrl, 0.0);
final qg2 = _p(_qg2Ctrl, 0.0);
final pd2 = _p(_pd2Ctrl, 0.0);
final qd2 = _p(_qd2Ctrl, 0.0);

final pg3 = _p(_pg3Ctrl, 0.0);
final qg3 = _p(_qg3Ctrl, 0.0);
final pd3 = _p(_pd3Ctrl, 0.0);
final qd3 = _p(_qd3Ctrl, 0.0);

final tol = _p(_tolCtrl, 1e-4);
final maxIterUI = _pi(_maxIterCtrl, 50).clamp(1, 500);
final fixedItersUI = _pi(_fixedIterCtrl, 2).clamp(1, 500);

final q1Min = (_bus1Type == BusKind.pv) ? _pNullable(_q1MinCtrl) : null;
final q1Max = (_bus1Type == BusKind.pv) ? _pNullable(_q1MaxCtrl) : null;

final q2Min = (_bus2Type == BusKind.pv) ? _pNullable(_q2MinCtrl) : null;
final q2Max = (_bus2Type == BusKind.pv) ? _pNullable(_q2MaxCtrl) : null;

final q3Min = (_bus3Type == BusKind.pv) ? _pNullable(_q3MinCtrl) : null;
final q3Max = (_bus3Type == BusKind.pv) ? _pNullable(_q3MaxCtrl) : null;

final ip = GS3Inputs(
lineDataInPu: _lineDataInPu,
useDirectYbus: _useDirectYbus,
bus1PowersInPu: _bus1PowersInPu,
bus2PowersInPu: _bus2PowersInPu,
bus3PowersInPu: _bus3PowersInPu,
iterateUntilConverge: iterate,
fixedItersRequestedUI: fixedItersUI,
tol: tol,
maxIterUI: maxIterUI,
bus1Type: _bus1Type,
bus2Type: _bus2Type,
bus3Type: _bus3Type,
slackGiven: _slackGiven,
sBaseMVA: sBaseMVA,
vBaseKV: vBaseKV,
r12: r12,
x12: x12,
r13: r13,
x13: x13,
r23: r23,
x23: x23,
y11Re: _p(_y11ReCtrl, 0.0),
y11Im: _p(_y11ImCtrl, 0.0),
y12Re: _p(_y12ReCtrl, 0.0),
y12Im: _p(_y12ImCtrl, 0.0),
y13Re: _p(_y13ReCtrl, 0.0),
y13Im: _p(_y13ImCtrl, 0.0),
y22Re: _p(_y22ReCtrl, 0.0),
y22Im: _p(_y22ImCtrl, 0.0),
y23Re: _p(_y23ReCtrl, 0.0),
y23Im: _p(_y23ImCtrl, 0.0),
y33Re: _p(_y33ReCtrl, 0.0),
y33Im: _p(_y33ImCtrl, 0.0),
v1Mag: v1Mag,
d1Deg: d1Deg,
v2Mag: v2Mag,
d2Deg: d2Deg,
v3Mag: v3Mag,
d3Deg: d3Deg,
pg1: pg1,
qg1: qg1,
pd1: pd1,
qd1: qd1,
pg2: pg2,
qg2: qg2,
pd2: pd2,
qd2: qd2,
pg3: pg3,
qg3: qg3,
pd3: pd3,
qd3: qd3,
q1Min: q1Min,
q1Max: q1Max,
q2Min: q2Min,
q2Max: q2Max,
q3Min: q3Min,
q3Max: q3Max,
);

final out = solveGs3WithWorkings(ip);

setState(() => res = out);
} catch (e) {
setState(() => _error = 'Error while solving: $e');
}
}

// LaTeX helpers 
Widget _lt(String latex, {double size = 14, FontWeight? weight, Color? color}) {
return Align(
alignment: Alignment.centerLeft,
child: FittedBox(
fit: BoxFit.scaleDown,
alignment: Alignment.centerLeft,
child: Math.tex(
latex,
mathStyle: MathStyle.text,
textStyle: TextStyle(fontSize: size, fontWeight: weight, color: color, height: 1.1),
),
),
);
}

Widget _ltMenu(String latex, {double size = 14, FontWeight? weight, Color? color}) {
return Math.tex(
latex,
mathStyle: MathStyle.text,
textStyle: TextStyle(fontSize: size, fontWeight: weight, color: color, height: 1.1),
);
}

// Labels above input fields, with optional units
String _latexLabelWithUnit(String latex, {String? unit, String? tail}) {
var s = latex;
final t = tail?.trim();
if (t != null && t.isNotEmpty) s += r'\ \text{' + t + '}';
final u = unit?.trim();
if (u != null && u.isNotEmpty) {
final looksLatex = u.contains(r'\') || u.contains('^') || u.contains('{') || u.contains('}');
if (looksLatex) {
if (u == r'^\circ') {
s += r'\;({}^\circ)';
} else {
s += r'\;(' + u + ')';
}
} else {
s += r'\;(\text{' + u + '})';
}
}
return s;
}

Widget latexNumField(
TextEditingController ctrl,
String latex, {
String? unit,
String? tail,
double width = 180,
bool enabled = true,
}) {
final label = _latexLabelWithUnit(latex, unit: unit, tail: tail);

const double labelHeight = 26;
const double gap = 4;

return SizedBox(
width: width,
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
SizedBox(
height: labelHeight,
child: Align(alignment: Alignment.centerLeft, child: _lt(label, size: 18, color: Colors.grey[800])),
),
const SizedBox(height: gap),
TextField(
controller: ctrl,
enabled: enabled,
keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9eE\+\-\.]'))],
decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
),
],
),
);
}

Widget latexIntField(
TextEditingController ctrl,
String latex, {
String? tail,
double width = 180,
bool enabled = true,
}) {
final label = _latexLabelWithUnit(latex, tail: tail);

const double labelHeight = 26;
const double gap = 4;

return SizedBox(
width: width,
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
SizedBox(
height: labelHeight,
child: Align(alignment: Alignment.centerLeft, child: _lt(label, size: 18, color: Colors.grey[800])),
),
const SizedBox(height: gap),
TextField(
controller: ctrl,
enabled: enabled,
keyboardType: TextInputType.number,
inputFormatters: [FilteringTextInputFormatter.digitsOnly],
decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
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
const Text('Bus Types & What You Solve', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
const SizedBox(height: 10),
latexLeft([
r'\textbf{Core idea}',
r'\textbf{Flat start: }\text{if Bus 2 is a load bus (PQ), set }|\vec V_2^{(0)}|=1,\ \delta_2^{(0)}=0^\circ.',
r'\textbf{But, If Bus 2 is a PV (generator) bus, set }|\vec V_2^{(0)}|=|V_2|_{\text{spec}},\ \delta_2^{(0)}=\delta_{2,\text{spec}}\ (\text{use }0^\circ\text{ if not given}).',
r'\textbf{Slack bus (Always Bus 1): }\text{set }|\vec V_1|=1,\ \delta_1=0^\circ\ \text{for all cases}.',
r'\textbf{Line Impedance }(\vec z_{ij}=R_{ij}+jX_{ij}):\ \text{impedance of the line between buses }i\text{ and }j.',
r'\text{Each bus carries four quantities: }V\ (\text{Magnitude}),\ \delta\ (\text{Phase angle of Voltage}),\ P\ (\text{Active Power}),\ Q\ (\text{Reactive Power}).',
r'\text{Net complex power at bus }i:\;\vec S_i=P_i+jQ_i=\vec S_{Gi}-\vec S_{Di}.',
r'\vec S_{Gi}=P_{Gi}+jQ_{Gi}.',
r'\vec S_{Di}=P_{Di}+jQ_{Di}.',
r'\text{Slack bus: }|\vec V|,\delta\ \text{specified; solve }P,Q.',
r'\text{PQ bus: }P,Q\ \text{specified; solve }|\vec V|,\delta.',
r'\text{PV bus: }P,|\vec V|\ \text{specified; solve }Q,\delta\ (\text{with Q-limits}).',
], size: 17),
const SizedBox(height: 10),
latexBlock([
r'\textbf{Types of buses \& what is specified / solved}',
r'\begin{array}{|l|c|c|}\hline',
r'\textbf{Bus} & \textbf{Specified quantities} & \textbf{Quantities to be determined} \\ \hline',
r'\text{Load (PQ)} & P,\ Q & |\vec V|,\ \delta \\ \hline',
r'\text{Generator (PV)} & P,\ |\vec V| & Q,\ \delta \\ \hline',
r'\text{Slack (V}\delta\text{)} & |\vec V|,\ \delta & P,\ Q \\ \hline',
r'\end{array}',
], size: 16),
],
),
),
);
}

// 3-bus diagram 
Widget _threeBusDiagramCard() {
double sNum(TextEditingController c, double fb) => _p(c, fb);
String s(double v, [int k = 4]) => sig(v, k);

// line impedances
final r12 = sNum(_r12Ctrl, 0.0);
final x12 = sNum(_x12Ctrl, 0.0);
final r13 = sNum(_r13Ctrl, 0.0);
final x13 = sNum(_x13Ctrl, 0.0);
final r23 = sNum(_r23Ctrl, 0.0);
final x23 = sNum(_x23Ctrl, 0.0);

final unitZ = _lineDataInPu ? r'\ \text{pu}' : r'\ \Omega';

final z12Latex = r'\vec z_{12}=' + s(r12) + r'+j' + s(x12) + unitZ;
final z13Latex = r'\vec z_{13}=' + s(r13) + r'+j' + s(x13) + unitZ;
final z23Latex = r'\vec z_{23}=' + s(r23) + r'+j' + s(x23) + unitZ;

// voltages
final v1m = sNum(_v1MagCtrl, 1.0);
final d1  = sNum(_d1Ctrl, 0.0);
final v2m = sNum(_v2MagCtrl, 1.0);
final d2  = sNum(_d2Ctrl, 0.0);
final v3m = sNum(_v3MagCtrl, 1.0);
final d3  = sNum(_d3Ctrl, 0.0);

final v1Latex = r'\vec V_1=' + s(v1m) + r'\angle ' + s(d1) + r'^\circ';
final v2Latex = r'\vec V_2=' + s(v2m) + r'\angle ' + s(d2) + r'^\circ';
final v3Latex = r'\vec V_3=' + s(v3m) + r'\angle ' + s(d3) + r'^\circ';

// powers 
final pg1 = sNum(_pg1Ctrl, 0.0), qg1 = sNum(_qg1Ctrl, 0.0);
final pd1 = sNum(_pd1Ctrl, 0.0), qd1 = sNum(_qd1Ctrl, 0.0);
final pg2 = sNum(_pg2Ctrl, 0.0), qg2 = sNum(_qg2Ctrl, 0.0);
final pd2 = sNum(_pd2Ctrl, 0.0), qd2 = sNum(_qd2Ctrl, 0.0);
final pg3 = sNum(_pg3Ctrl, 0.0), qg3 = sNum(_qg3Ctrl, 0.0);
final pd3 = sNum(_pd3Ctrl, 0.0), qd3 = sNum(_qd3Ctrl, 0.0);

// Units: if in pu, attach 'pu' to the end; if in physical units, attach 'MW' to P and 'Mvar' to Q
String sComplexPQ(double p, double q, bool inPu) {
if (inPu) {
// keep your original compact style for pu
return s(p) + r'+j' + s(q) + r'\ \text{pu}';
}
// unit attaches to each term 
return s(p) + r'\ \text{MW}+j' + s(q) + r'\ \text{Mvar}';
}

final sg1Latex = r'\vec S_{G1}=' + sComplexPQ(pg1, qg1, _bus1PowersInPu);
final sd1Latex = r'\vec S_{D1}=' + sComplexPQ(pd1, qd1, _bus1PowersInPu);

final sg2Latex = r'\vec S_{G2}=' + sComplexPQ(pg2, qg2, _bus2PowersInPu);
final sd2Latex = r'\vec S_{D2}=' + sComplexPQ(pd2, qd2, _bus2PowersInPu);

final sg3Latex = r'\vec S_{G3}=' + sComplexPQ(pg3, qg3, _bus3PowersInPu);
final sd3Latex = r'\vec S_{D3}=' + sComplexPQ(pd3, qd3, _bus3PowersInPu);

// Optional Q-limit
final q2min = _pNullable(_q2MinCtrl), q2max = _pNullable(_q2MaxCtrl);
final q3min = _pNullable(_q3MinCtrl), q3max = _pNullable(_q3MaxCtrl);

String? qLimLatex({
required bool showIt,
required double? qmin,
required double? qmax,
required String sub,
required bool inPu, 
}) {
if (!showIt) return null;
if (qmin == null && qmax == null) return null;
final lo = (qmin == null) ? r'-\infty' : s(qmin, 4);
final hi = (qmax == null) ? r'+\infty' : s(qmax, 4);
return r'Q_{g' + sub + r'}\in[' + lo + r',' + hi + r']\ \text{pu}';
}

final q2Lim = qLimLatex(
showIt: _bus2Type == BusKind.pv,
qmin: q2min,
qmax: q2max,
sub: '2',
inPu: _bus2PowersInPu,
);

final q3Lim = qLimLatex(
showIt: _bus3Type == BusKind.pv,
qmin: q3min,
qmax: q3max,
sub: '3',
inPu: _bus3PowersInPu,
);

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
height: 210,
width: double.infinity,
child: LayoutBuilder(
builder: (context, constraints) {
const double imgAspect = 2.8;

final rect = _containRect(
  containerW: constraints.maxWidth,
  containerH: 210,
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
        'assets/diagrams/3bus_model.png',
        fit: BoxFit.fill,
      ),
    ),

    // Line impedances
    _diagLabelFrac(rect, x: 0.38, y: 0.06, latex: z12Latex, size: 14.5),
    _diagLabelFrac(rect, x: 0.08, y: 0.53, latex: z13Latex, size: 14.5),
    _diagLabelFrac(rect, x: 0.67, y: 0.53, latex: z23Latex, size: 14.5),

    // Voltages
    _diagLabelFrac(rect, x: -0.14, y: 0.16, latex: v1Latex, size: 14.5),
    _diagLabelFrac(rect, x: 0.95, y: 0.16, latex: v2Latex, size: 14.5),
    _diagLabelFrac(rect, x: 0.57, y: 0.75, latex: v3Latex, size: 14.5),

    // Powers 
    _diagLabelFrac(rect, x: -0.14, y: 0.02, latex: sg1Latex, size: 13.6),
    _diagLabelFrac(rect, x: -0.03, y: 0.38, latex: sd1Latex, size: 13.6),

    _diagLabelFrac(rect, x: 0.93, y: 0.02, latex: sg2Latex, size: 13.6),
    _diagLabelFrac(rect, x: 0.86, y: 0.38, latex: sd2Latex, size: 13.6),

    _diagLabelFrac(rect, x: 0.14, y: 0.80, latex: sg3Latex, size: 13.2),
    _diagLabelFrac(rect, x: 0.50, y: 0.87, latex: sd3Latex, size: 13.2),

    // Q-limit labels only for PV buses
    if (q2Lim != null) _diagLabelFrac(rect, x: 0.95, y: 0.27, latex: q2Lim!, size: 12.5),
    if (q3Lim != null) _diagLabelFrac(rect, x: 0.60, y: 0.66, latex: q3Lim!, size: 12.0),
  ],
);
},
),
),
),
],
),
),
);
}

// Inputs Card
Widget _inputsCard() {
Widget latexDropdown<T>({
required T value,
required List<T> values,
required String Function(T) latexOf,
required ValueChanged<T?> onChanged,
double minWidth = 140,
}) {
return DropdownButton<T>(
value: value,
items: values
.map((t) => DropdownMenuItem<T>(
value: t,
child: ConstrainedBox(
  constraints: BoxConstraints(minWidth: minWidth),
  child: _ltMenu(latexOf(t), size: 17.0),
),
))
.toList(),
onChanged: onChanged,
);
}

String busKindLatex(BusKind t) {
switch (t) {
case BusKind.slack:
return r'\text{SLACK }(V\angle\delta)';
case BusKind.pv:
return r'\text{GENERATOR }(PV)';
case BusKind.pq:
return r'\text{LOAD }(PQ)';
}
}

String slackGivenLatex(SlackGiven g) {
switch (g) {
case SlackGiven.none:
return r'\text{None (optional)}';
case SlackGiven.sg1Given:
return r'\vec S_{g1}\ \text{is given}';
case SlackGiven.sd1Given:
return r'\vec S_{d1}\ \text{is given}';
}
}

return Card(
child: Padding(
padding: const EdgeInsets.all(16.0),
child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
_lt(r'\textbf{3-bus inputs (solver logic follows your dropdown selections)}', size: 15.0, weight: FontWeight.w700),
const SizedBox(height: 10),

_threeBusDiagramCard(),
const SizedBox(height: 14),

// PRESET
softBox(
Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
_lt(r'\textbf{Quick Fill Preset}', size: 17.0, weight: FontWeight.w700),
const SizedBox(height: 8),
Row(
children: [
  Expanded(
    child: DropdownButtonFormField<GS3Preset>(
      isExpanded: true,
      value: _selectedPreset,
      decoration: const InputDecoration(labelText: 'Preset', isDense: true, border: OutlineInputBorder()),
      items: _presets.map((p) => DropdownMenuItem<GS3Preset>(value: p, child: Text(p.name, overflow: TextOverflow.ellipsis))).toList(),
      onChanged: (p) => setState(() => _selectedPreset = p),
    ),
  ),
  const SizedBox(width: 10),
  FilledButton(onPressed: (_selectedPreset == null) ? null : () => _applyPreset(_selectedPreset!), child: const Text('Apply')),
  const SizedBox(width: 8),
  OutlinedButton(onPressed: () => setState(() => _selectedPreset = null), child: const Text('Clear')),
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

_lt(r'\textbf{Base + line data}', size: 15.0, weight: FontWeight.w700),
const SizedBox(height: 8),

Row(children: [
_lt(r'\textbf{Line data already in per-unit?}', size: 15.0, color: _useDirectYbus ? Colors.grey : null),
const SizedBox(width: 10),
Switch(value: _lineDataInPu, onChanged: _useDirectYbus ? null : (v) => setState(() => _lineDataInPu = v)),
]),
const SizedBox(height: 6),

Row(children: [
_lt(r'\textbf{Input Y-bus matrix directly?}', size: 15.0, weight: FontWeight.w700),
const SizedBox(width: 10),
Switch(value: _useDirectYbus, onChanged: (v) => setState(() => _useDirectYbus = v)),
]),
const SizedBox(height: 10),

if (!_useDirectYbus) ...[
Wrap(spacing: 12, runSpacing: 12, children: [
latexNumField(_sBaseCtrl, r'S_{\text{base}}', unit: 'MVA'),
latexNumField(_vBaseCtrl, r'V_{\text{base}}', unit: 'kV'),
]),
const SizedBox(height: 12),
Wrap(spacing: 12, runSpacing: 12, children: [
latexNumField(_r12Ctrl, r'R_{12}', unit: _lineDataInPu ? 'pu' : r'\Omega'),
latexNumField(_x12Ctrl, r'X_{12}', unit: _lineDataInPu ? 'pu' : r'\Omega'),
]),
const SizedBox(height: 12),
Wrap(spacing: 12, runSpacing: 12, children: [
latexNumField(_r13Ctrl, r'R_{13}', unit: _lineDataInPu ? 'pu' : r'\Omega'),
latexNumField(_x13Ctrl, r'X_{13}', unit: _lineDataInPu ? 'pu' : r'\Omega'),
]),
const SizedBox(height: 12),
Wrap(spacing: 12, runSpacing: 12, children: [
latexNumField(_r23Ctrl, r'R_{23}', unit: _lineDataInPu ? 'pu' : r'\Omega'),
latexNumField(_x23Ctrl, r'X_{23}', unit: _lineDataInPu ? 'pu' : r'\Omega'),
]),
] else ...[
_lt(r'\textbf{Y-bus matrix (per-unit)}', size: 14.6, weight: FontWeight.w700, color: Colors.indigo),
const SizedBox(height: 6),
_lt(r'\text{Enter real and imaginary parts. }Y_{21}=Y_{12},\ Y_{31}=Y_{13},\ Y_{32}=Y_{23}\ \text{(symmetric).}', size: 18.0, color: Colors.grey[700]),
const SizedBox(height: 10),
Wrap(spacing: 12, runSpacing: 12, children: [
latexNumField(_y11ReCtrl, r'\Re\{Y_{11}\}'),
latexNumField(_y11ImCtrl, r'\Im\{Y_{11}\}'),
latexNumField(_y12ReCtrl, r'\Re\{Y_{12}\}'),
latexNumField(_y12ImCtrl, r'\Im\{Y_{12}\}'),
latexNumField(_y13ReCtrl, r'\Re\{Y_{13}\}'),
latexNumField(_y13ImCtrl, r'\Im\{Y_{13}\}'),
]),
const SizedBox(height: 12),
Wrap(spacing: 12, runSpacing: 12, children: [
latexNumField(_y22ReCtrl, r'\Re\{Y_{22}\}'),
latexNumField(_y22ImCtrl, r'\Im\{Y_{22}\}'),
latexNumField(_y23ReCtrl, r'\Re\{Y_{23}\}'),
latexNumField(_y23ImCtrl, r'\Im\{Y_{23}\}'),
]),
const SizedBox(height: 12),
Wrap(spacing: 12, runSpacing: 12, children: [
latexNumField(_y33ReCtrl, r'\Re\{Y_{33}\}'),
latexNumField(_y33ImCtrl, r'\Im\{Y_{33}\}'),
]),
],

const SizedBox(height: 18),

// Bus 1
Row(children: [
_lt(r'\textbf{Bus 1}', size: 18.0, weight: FontWeight.w700),
const SizedBox(width: 12),
latexDropdown<BusKind>(value: _bus1Type, values: BusKind.values, latexOf: busKindLatex, onChanged: (nv) => setState(() => _bus1Type = nv ?? BusKind.slack), minWidth: 170),
const SizedBox(width: 16),
_lt(r'\text{Given at Bus 1:}', size: 18.0),
const SizedBox(width: 10),
latexDropdown<SlackGiven>(value: _slackGiven, values: SlackGiven.values, latexOf: slackGivenLatex, onChanged: (nv) => setState(() => _slackGiven = nv ?? SlackGiven.none), minWidth: 190),
const Spacer(),
_lt(r'\text{Bus 1 powers in per unit (pu)?}', size: 18.0),
const SizedBox(width: 8),
Switch(value: _bus1PowersInPu, onChanged: (v) => setState(() => _bus1PowersInPu = v)),
]),
const SizedBox(height: 8),
Wrap(spacing: 12, runSpacing: 12, children: [
latexNumField(_v1MagCtrl, r'|V_1|', unit: 'pu'),
latexNumField(_d1Ctrl, r'\delta_1', unit: r'^\circ'),
]),
const SizedBox(height: 10),
Wrap(spacing: 12, runSpacing: 12, children: [
latexNumField(_pg1Ctrl, r'P_{g1}', unit: _bus1PowersInPu ? 'pu' : 'MW'),
latexNumField(_qg1Ctrl, r'Q_{g1}', unit: _bus1PowersInPu ? 'pu' : 'Mvar'),
latexNumField(_pd1Ctrl, r'P_{d1}', unit: _bus1PowersInPu ? 'pu' : 'MW'),
latexNumField(_qd1Ctrl, r'Q_{d1}', unit: _bus1PowersInPu ? 'pu' : 'Mvar'),
]),

const SizedBox(height: 18),

// Bus 2
Row(children: [
_lt(r'\textbf{Bus 2}', size: 18.0, weight: FontWeight.w700),
const SizedBox(width: 12),
latexDropdown<BusKind>(value: _bus2Type, values: BusKind.values, latexOf: busKindLatex, onChanged: (nv) => setState(() => _bus2Type = nv ?? BusKind.pq), minWidth: 170),
const Spacer(),
_lt(r'\text{Bus 2 powers in per unit (pu)?}', size: 18.0),
const SizedBox(width: 8),
Switch(value: _bus2PowersInPu, onChanged: (v) => setState(() => _bus2PowersInPu = v)),
]),
const SizedBox(height: 8),
Wrap(spacing: 12, runSpacing: 12, children: [
latexNumField(_v2MagCtrl, r'|V_2|', unit: 'pu'),
latexNumField(_d2Ctrl, r'\delta_2', unit: r'^\circ'),
]),
const SizedBox(height: 10),
Wrap(spacing: 12, runSpacing: 12, children: [
latexNumField(_pg2Ctrl, r'P_{g2}', unit: _bus2PowersInPu ? 'pu' : 'MW'),
latexNumField(_qg2Ctrl, r'Q_{g2}', unit: _bus2PowersInPu ? 'pu' : 'Mvar'),
latexNumField(_pd2Ctrl, r'P_{d2}', unit: _bus2PowersInPu ? 'pu' : 'MW'),
latexNumField(_qd2Ctrl, r'Q_{d2}', unit: _bus2PowersInPu ? 'pu' : 'Mvar'),
]),
if (_bus2Type == BusKind.pv) ...[
const SizedBox(height: 12),
_lt(r'\textbf{PV Q-limits (generator-side, optional)}', size: 14.6, weight: FontWeight.w700),
const SizedBox(height: 8),
Wrap(spacing: 12, runSpacing: 12, children: [
latexNumField(_q2MinCtrl, r'Q_{g2,\min}', unit: 'pu'),
latexNumField(_q2MaxCtrl, r'Q_{g2,\max}', unit: 'pu'),
]),
],

const SizedBox(height: 18),

// Bus 3
Row(children: [
_lt(r'\textbf{Bus 3}', size: 18, weight: FontWeight.w700),
const SizedBox(width: 12),
latexDropdown<BusKind>(value: _bus3Type, values: BusKind.values, latexOf: busKindLatex, onChanged: (nv) => setState(() => _bus3Type = nv ?? BusKind.pq), minWidth: 170),
const Spacer(),
_lt(r'\text{Bus 3 powers in per unit (pu)?}', size: 18.0),
const SizedBox(width: 8),
Switch(value: _bus3PowersInPu, onChanged: (v) => setState(() => _bus3PowersInPu = v)),
]),
const SizedBox(height: 8),
Wrap(spacing: 12, runSpacing: 12, children: [
latexNumField(_v3MagCtrl, r'|V_3|', unit: 'pu'),
latexNumField(_d3Ctrl, r'\delta_3', unit: r'^\circ'),
]),
const SizedBox(height: 10),
Wrap(spacing: 12, runSpacing: 12, children: [
latexNumField(_pg3Ctrl, r'P_{g3}', unit: _bus3PowersInPu ? 'pu' : 'MW'),
latexNumField(_qg3Ctrl, r'Q_{g3}', unit: _bus3PowersInPu ? 'pu' : 'Mvar'),
latexNumField(_pd3Ctrl, r'P_{d3}', unit: _bus3PowersInPu ? 'pu' : 'MW'),
latexNumField(_qd3Ctrl, r'Q_{d3}', unit: _bus3PowersInPu ? 'pu' : 'Mvar'),
]),
if (_bus3Type == BusKind.pv) ...[
const SizedBox(height: 12),
_lt(r'\textbf{PV Q-limits (generator-side, optional)}', size: 14.6, weight: FontWeight.w700),
const SizedBox(height: 8),
Wrap(spacing: 12, runSpacing: 12, children: [
latexNumField(_q3MinCtrl, r'Q_{g3,\min}', unit: 'pu'),
latexNumField(_q3MaxCtrl, r'Q_{g3,\max}', unit: 'pu'),
]),
],

const SizedBox(height: 18),

_lt(r'\textbf{Iteration settings}', size: 18.0, weight: FontWeight.w700),
const SizedBox(height: 8),

softBox(
Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
_lt(r'\textbf{Iteration modes}', size: 17.0, weight: FontWeight.w700),
const SizedBox(height: 6),
_lt(r'\text{Convergence ON: stop when difference < Convergence Tolerance (or max iterations).}', size: 16.0, color: Colors.grey[700]),
_lt(r'\text{Convergence OFF: run exactly }k\text{ Gauss–Seidel iterations.}', size: 16.0, color: Colors.grey[700]),
]),
),
const SizedBox(height: 10),

Wrap(spacing: 12, runSpacing: 12, children: [
latexNumField(_tolCtrl, r'\text{Convergence tolerance (max }|\Delta x|_{\max}\text{)}', width: 300),
latexIntField(_maxIterCtrl, r'\text{max iterations}', width: 300),
]),
const SizedBox(height: 12),

Row(children: [
Switch(value: iterate, onChanged: (v) => setState(() => iterate = v)),
const SizedBox(width: 10),
_lt(r'\text{Iterate }V_2\text{ and }V_3\text{ until convergence}', size: 18.0),
]),

if (!iterate) ...[
const SizedBox(height: 10),
softBox(
Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
_lt(r'\textbf{Fixed-iteration mode}', size: 14.6, weight: FontWeight.w700),
const SizedBox(height: 10),
latexIntField(_fixedIterCtrl, r'\text{Number of iterations }(k)', width: 220),
const SizedBox(height: 8),
_lt(r'\text{When convergence is OFF, the solver will run exactly (k-times) Gauss–Seidel iterations.}', size: 16.0, color: Colors.grey[700]),
]),
),
],
]),
),
);
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

// Inputs
for (final c in [
// line data
_r12Ctrl, _x12Ctrl,
_r13Ctrl, _x13Ctrl,
_r23Ctrl, _x23Ctrl,

// voltages
_v1MagCtrl, _d1Ctrl,
_v2MagCtrl, _d2Ctrl,
_v3MagCtrl, _d3Ctrl,

// powers
_pg1Ctrl, _qg1Ctrl, _pd1Ctrl, _qd1Ctrl,
_pg2Ctrl, _qg2Ctrl, _pd2Ctrl, _qd2Ctrl,
_pg3Ctrl, _qg3Ctrl, _pd3Ctrl, _qd3Ctrl,

// optional Q-limits
_q1MinCtrl, _q1MaxCtrl,
_q2MinCtrl, _q2MaxCtrl,
_q3MinCtrl, _q3MaxCtrl,
]) {
listen(c);
}
}

// UI 
@override
Widget build(BuildContext context) {
return Scaffold(
appBar: AppBar(title: const Text('Gauss-Seidel 3-Bus Solver')),
body: SingleChildScrollView(
padding: const EdgeInsets.all(16),
child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
_busTypesExplainer(),
const SizedBox(height: 18),
_inputsCard(),
const SizedBox(height: 12),
Wrap(spacing: 8, runSpacing: 8, children: [
FilledButton(onPressed: _compute, child: const Text('Compute')),
FilledButton.tonal(onPressed: () => setState(() => mode = DisplayMode.rect), child: const Text('Show Rect')),
FilledButton.tonal(onPressed: () => setState(() => mode = DisplayMode.polar), child: const Text('Show Polar')),
FilledButton.tonal(onPressed: () => setState(() => mode = DisplayMode.both), child: const Text('Show Both')),
]),
const SizedBox(height: 16),
if (_error != null) Text(_error!, style: TextStyle(color: Colors.red[700])),
if (res != null) _steps(res!),
if (res == null && _error == null)
const Padding(
padding: EdgeInsets.only(top: 28),
child: Center(child: Text('Enter data and tap Compute to see the step-by-step workings.')),
),
]),
),
);
}


// Stepper 
Widget _steps(GS3Result r) {
String rect(C z) {
final s = z.im >= 0 ? '+' : '-';
return '${sig(z.re)}\\, $s\\, j${sig(z.im.abs())}';
}

String polar(C z) => '${sig(z.abs())}\\angle ${sig(z.angDeg())}^{\\circ}';

String show(C z) {
if (mode == DisplayMode.rect) return rect(z);
if (mode == DisplayMode.polar) return polar(z);
return rect(z) + r'\;=\;' + polar(z);
}

String rectN(C z, int n) {
final s = z.im >= 0 ? '+' : '-';
return '${sig(z.re, n)}\\, $s\\, j${sig(z.im.abs(), n)}';
}

String showN(C z, int n) {
if (mode == DisplayMode.rect) return rectN(z, n);
if (mode == DisplayMode.polar) return polar(z);
return rectN(z, n) + r'\;=\;' + polar(z);
}

// Step 4 display helpers 
final term21_gs0 = r.Y21 * r.V1;
final term23_gs0 = r.Y23 * r.V3_0_forGS;     
final term31_gs0 = r.Y31 * r.V1;
final term32_gs1 = r.Y32 * r.V2new;          

String matRect(List<List<C>> m) {
final rows = m.map((row) => row.map((z) => rectPretty(z)).join(r' & ')).join(r' \\ ');
return r'\begin{bmatrix}' + rows + r'\end{bmatrix}';
}

String matPolar(List<List<C>> m) {
String pCell(C z) => '${sig(z.abs())}\\angle ${sig(z.angDeg())}^{\\circ}';
final rows = m.map((row) => row.map(pCell).join(r' & ')).join(r' \\ ');
return r'\begin{bmatrix}' + rows + r'\end{bmatrix}';
}

final includePVStep = (r.bus2Type == BusKind.pv) || (r.bus3Type == BusKind.pv);

final prodPV2 = r.prodPV2_0;
final prodPV3 = r.prodPV3_0;

// Step 6 Slack bus power 
final I11_term = r.Y11 * r.V1;
final I12_term = r.Y12 * r.V2final;
final I13_term = r.Y13 * r.V3final;
final I1_sum = I11_term + I12_term + I13_term;
final I1_star = I1_sum.conj();
final S1_calc = r.V1 * I1_star;

final P1_pu = S1_calc.re;
final Q1_pu = S1_calc.im;

final P1_MW = P1_pu * r.sBaseMVA;
final Q1_Mvar = Q1_pu * r.sBaseMVA;

// Step 7 Line flows & losses
final V12 = r.V1 - r.V2final;
final I12_calc = r.y12 * V12;
final I12_star = I12_calc.conj();
final S12_calc = r.V1 * I12_star;

final V21 = r.V2final - r.V1;
final I21_calc = r.y12 * V21;
final I21_star = I21_calc.conj();
final S21_calc = r.V2final * I21_star;
final Sloss12_calc = S12_calc + S21_calc;

final V13 = r.V1 - r.V3final;
final I13_calc = r.y13 * V13;
final I13_star = I13_calc.conj();
final S13_calc = r.V1 * I13_star;

final V31 = r.V3final - r.V1;
final I31_calc = r.y13 * V31;
final I31_star = I31_calc.conj();
final S31_calc = r.V3final * I31_star;
final Sloss13_calc = S13_calc + S31_calc;

final V23 = r.V2final - r.V3final;
final I23_calc = r.y23 * V23;
final I23_star = I23_calc.conj();
final S23_calc = r.V2final * I23_star;

final V32 = r.V3final - r.V2final;
final I32_calc = r.y23 * V32;
final I32_star = I32_calc.conj();
final S32_calc = r.V3final * I32_star;
final Sloss23_calc = S23_calc + S32_calc;

final SlossTotal_calc = Sloss12_calc + Sloss13_calc + Sloss23_calc;

final step1Title = '1) Convert z (Line Impedance) → y (Line Admittance) and build Y Bus Admittance Matrix';
final step2Title = '2) Specify buses, convert powers to pu, and set initial voltages';
final step3Title = '3) PV reactive power and Q-limits (generator-side)';
final step4Title = includePVStep ? '4) Gauss-seidel update for V₂, V₃ and first Gauss-Seidel Iteration' : '3) Gauss-seidel update for V₂, V₃ and first Gauss-Seidel Iteration';

// Update titles based on whether PV step is included
final step5Title = includePVStep
? (r.iterate ? '5) Iterate V₂ & V₃ until convergence (table)' : '5) Iterations (k-times)')
: (r.iterate ? '4) Iterate V₂ & V₃ until convergence (table)' : '4) Iterations (k-times)');

final step6Title = includePVStep ? '6) Slack bus real and reactive power' : '5) Slack bus real and reactive power';
final step7Title = includePVStep ? '7) Line flows and line losses' : '6) Line flows and line losses';

final steps = <Step>[
// Step 1
Step(
isActive: true,
title: Text(step1Title),
content: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
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
r'\text{Line Impedance }(\vec z_{ij}=R_{ij}+jX_{ij}):\ \text{impedance between each line.}',
r'\text{Line Admittance }(\vec y_{ij}):\ \text{admittance between each line.}',
r'\text{Self-Admittance }(\vec Y_{ii}):\ \text{diagonal elements of }\mathbf{\vec Y}_{\text{bus}}\ =\ \text{sum of incident }\vec y_{ij}.',
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
r'\vec z_{12}=' +
sig(r.r12) +
r' + j' +
sig(r.x12) +
(r.lineDataInPu ? r'\ (\text{pu})' : r'\ (\Omega)') +
r',\quad \vec z_{13}=' +
sig(r.r13) +
r' + j' +
sig(r.x13) +
(r.lineDataInPu ? r'\ (\text{pu})' : r'\ (\Omega)') +
r',\quad \vec z_{23}=' +
sig(r.r23) +
r' + j' +
sig(r.x23) +
(r.lineDataInPu ? r'\ (\text{pu})' : r'\ (\Omega)') +
r'.',
], size: 16.5),
const SizedBox(height: 10),
if (r.lineDataInPu) ...[
softBox(
latexLeft([
r'\textbf{Inputs already in per-unit}',
r'\vec z_{12,\text{pu}}=' + show(r.z12pu) + r',\quad \vec z_{13,\text{pu}}=' + show(r.z13pu) + r',\quad \vec z_{23,\text{pu}}=' + show(r.z23pu) + r'.',
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
r'\vec z_{12,\text{pu}}=\dfrac{\vec z_{12,\Omega}}{Z_{\text{base}}}=' +
    show(r.z12pu) +
    r',\quad'
        r'\vec z_{13,\text{pu}}=' +
    show(r.z13pu) +
    r',\quad'
        r'\vec z_{23,\text{pu}}=' +
    show(r.z23pu) +
    r'.',
], size: 16),
),
const SizedBox(height: 12),
],
latexBlock([r'\textbf{Line admittances (series)}'], size: 17),
const SizedBox(height: 6),
latexLeft([
r'\vec y_{ij}=\dfrac{1}{\vec z_{ij,\text{pu}}}',
r'\vec y_{12}=\dfrac{1}{\vec z_{12,\text{pu}}}=\dfrac{1}{(' + rect(r.z12pu) + r')}=' + show(r.y12),
r'\vec y_{13}=\dfrac{1}{\vec z_{13,\text{pu}}}=\dfrac{1}{(' + rect(r.z13pu) + r')}=' + show(r.y13),
r'\vec y_{23}=\dfrac{1}{\vec z_{23,\text{pu}}}=\dfrac{1}{(' + rect(r.z23pu) + r')}=' + show(r.y23),
], size: 16.5),
const SizedBox(height: 12),
latexBlock([r'\boxed{\textbf{Diagonals (Self-Admittance):}\ \vec Y_{ii}=\sum_{j=1}^{n}\vec y_{ij}}'], size: 16.5),
const SizedBox(height: 8),
latexLeft([
r'\vec Y_{11}=\vec y_{12}+\vec y_{13}=(' +
rect(r.y12) +
r')+(' +
rect(r.y13) +
r')=' +
rect(r.Y11) +
(mode == DisplayMode.rect ? r'.' : r'\;=\;' + polar(r.Y11) + r'.'),
r'\vec Y_{22}=\vec y_{21}+\vec y_{23}=\vec y_{12}+\vec y_{23}=(' +
rect(r.y12) +
r')+(' +
rect(r.y23) +
r')=' +
rect(r.Y22) +
(mode == DisplayMode.rect ? r'.' : r'\;=\;' + polar(r.Y22) + r'.'),
r'\vec Y_{33}=\vec y_{31}+\vec y_{32}=\vec y_{13}+\vec y_{23}=(' +
rect(r.y13) +
r')+(' +
rect(r.y23) +
r')=' +
rect(r.Y33) +
(mode == DisplayMode.rect ? r'.' : r'\;=\;' + polar(r.Y33) + r'.'),
], size: 16.5),
const SizedBox(height: 12),
latexBlock([r'\boxed{\textbf{Off-Diagonals (Mutual/Transfer Admittance):}\ \vec Y_{ij}=-\vec y_{ij}\ (i\neq j)}'], size: 16.5),
const SizedBox(height: 8),
latexLeft([
r'\vec Y_{12}=\vec Y_{21}=-\vec y_{12}=-( ' +
rect(r.y12) +
r')=' +
rect(r.Y12) +
(mode == DisplayMode.rect ? r'.' : r'\;=\;' + polar(r.Y12) + r'.'),
r'\vec Y_{13}=\vec Y_{31}=-\vec y_{13}=-( ' +
rect(r.y13) +
r')=' +
rect(r.Y13) +
(mode == DisplayMode.rect ? r'.' : r'\;=\;' + polar(r.Y13) + r'.'),
r'\vec Y_{23}=\vec Y_{32}=-\vec y_{23}=-( ' +
rect(r.y23) +
r')=' +
rect(r.Y23) +
(mode == DisplayMode.rect ? r'.' : r'\;=\;' + polar(r.Y23) + r'.'),
], size: 16.5),
const SizedBox(height: 14),
latexBlock([
r'\textbf{Build }\mathbf{\vec Y}_{\text{bus}}\textbf{ (no line charging / shunt neglected)}',
r'\vec Y_{ii}=\sum \vec y_{ij},\quad \vec Y_{ij}=-\vec y_{ij}\ (i\ne j).',
], size: 16.5),
const SizedBox(height: 10),
if (mode == DisplayMode.both) ...[
latexBlock([r'\mathbf{\vec Y}_{\text{bus}}^{\text{rect}}=' + matRect(r.Ybus)]),
const SizedBox(height: 10),
latexBlock([r'\mathbf{\vec Y}_{\text{bus}}^{\text{polar}}=' + matPolar(r.Ybus)]),
] else ...[
latexBlock([r'\mathbf{\vec Y}_{\text{bus}}=' + (mode == DisplayMode.rect ? matRect(r.Ybus) : matPolar(r.Ybus))]),
],
],
),
),

// Step 2
Step(
isActive: true,
title: Text(step2Title),
content: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
latexLeft([
r'\textbf{Bus types (from your dropdowns)}',
r'\text{Bus 1: }' +
(r.bus1Type == BusKind.slack
? r'\text{Slack (V}\delta\text{)}'
: r.bus1Type == BusKind.pv
  ? r'\text{PV}'
  : r'\text{PQ}') +
r',\quad \text{Bus 2: }' +
(r.bus2Type == BusKind.slack
? r'\text{Slack}'
: r.bus2Type == BusKind.pv
  ? r'\text{PV}'
  : r'\text{PQ}') +
r',\quad \text{Bus 3: }' +
(r.bus3Type == BusKind.slack
? r'\text{Slack}'
: r.bus3Type == BusKind.pv
  ? r'\text{PV}'
  : r'\text{PQ}') +
r'.',
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
r'\textbf{Slack extra info: }' +
(r.slackGiven == SlackGiven.sg1Given
? r'\text{You selected “}S_{G1}\text{ is given” (we will solve }S_{D1}\text{ after }S_{1,\text{net}}\text{).}'
: (r.slackGiven == SlackGiven.sd1Given
  ? r'\text{You selected “}S_{D1}\text{ is given” (we will solve }S_{G1}\text{).}'
  : r'\text{None selected (we treat entered }S_{D1}\text{ as given; default is 0).}')),
], size: 16.5),
const SizedBox(height: 10),

// BOXED: Bus 2 conversion
softBox(
latexLeft([
r'\textbf{Bus 2 conversion}',
if (!r.bus2PowersInPu) ...[
r'P_{d2,\text{pu}}=\dfrac{P_{d2,\text{MW actual}}}{S_{\text{base}}}'
r'=\dfrac{' +
sig(double.tryParse(_pd2Ctrl.text) ?? 0) +
r'}{' +
sig(r.sBaseMVA) +
r'}=' +
sig(r.Pd2) +
r'\ \text{pu}.',
r'Q_{d2,\text{pu}}=\dfrac{Q_{d2,\text{Mvar actual}}}{S_{\text{base}}}'
r'=\dfrac{' +
sig(double.tryParse(_qd2Ctrl.text) ?? 0) +
r'}{' +
sig(r.sBaseMVA) +
r'}=' +
sig(r.Qd2) +
r'\ \text{pu}.',
] else ...[
r'\text{Inputs already in per-unit: }'
r'P_{d2,\text{pu}}=' +
sig(r.Pd2) +
r',\quad Q_{d2,\text{pu}}=' +
sig(r.Qd2) +
r',\ P_{g2,\text{pu}}=' +
sig(r.Pg2)+
r',\ Q_{g2,\text{pu}}=' +
sig(r.Qg2)+
r'.',
],
r'\vec S_{D2}=P_{d2, pu}+jQ_{d2, pu}=' + show(r.Sd2) + r'.',
r'\vec S_{G2}=P_{g2, pu}+jQ_{g2, pu}=' + show(C(r.Pg2, r.Qg2)) + r'.',
r'\Rightarrow\ \vec S_2=\vec S_{G2}-\vec S_{D2}=' + show(r.S2spec) + r'.',
if (r.bus2Type == BusKind.pv)
r'\textbf{(PV)}\ \text{Only }P_2\text{ and }|\vec V_2|\text{ are specified; }Q_2\text{ will be computed in the next step.}',
], size: 16),
),
const SizedBox(height: 12),

// BOXED: Bus 3 conversion
softBox(
latexLeft([
r'\textbf{Bus 3 conversion}',
if (!r.bus3PowersInPu) ...[
r'P_{d3,\text{pu}}=\dfrac{P_{d3,\text{MW actual}}}{S_{\text{base}}}'
r'=\dfrac{' +
sig(double.tryParse(_pd3Ctrl.text) ?? 0) +
r'}{' +
sig(r.sBaseMVA) +
r'}=' +
sig(r.Pd3) +
r'\ \text{pu}.',
r'Q_{d3,\text{pu}}=\dfrac{Q_{d3,\text{Mvar actual}}}{S_{\text{base}}}'
r'=\dfrac{' +
sig(double.tryParse(_qd3Ctrl.text) ?? 0) +
r'}{' +
sig(r.sBaseMVA) +
r'}=' +
sig(r.Qd3) +
r'\ \text{pu}.',
] else ...[
r'\text{Inputs already in per-unit: }'
r'P_{d3,\text{pu}}=' +
sig(r.Pd3) +
r',\quad Q_{d3,\text{pu}}=' +
sig(r.Qd3) +
r',\ P_{g2,\text{pu}}=' +
sig(r.Pg3)+
r',\ Q_{g2,\text{pu}}=' +
sig(r.Qg3)+
r'.',
],
r'\vec S_{D3}=P_{d3, pu}+jQ_{d3, pu}=' + show(r.Sd3) + r'.',
r'\vec S_{G3}=P_{g3, pu}+jQ_{g3, pu}=' + show(C(r.Pg3, r.Qg3)) + r'.',
r'\Rightarrow\ \vec S_3=\vec S_{G3}-\vec S_{D3}=' + show(r.S3spec) + r'.',
if (r.bus3Type == BusKind.pv)
r'\textbf{(PV)}\ \text{Only }P_3\text{ and }|\vec V_3|\text{ are specified; }Q_3\text{ will be computed in the next step.}',
], size: 16),
),
const SizedBox(height: 12),

latexLeft([
r'\textbf{Voltages (phasors)}',
r'\vec V_1=|\vec V_1|\angle\delta_1=' + show(r.V1) + r'\quad (\text{reference voltage}).',
r'\textbf{Remember to Set Flat Start }\;1\angle 0^\circ\;\textbf{ (For PQ, Load Buses), if not:}',
r'\vec V_2^{(0)}=' + show(r.V2_0_input) + r',\quad \vec V_3^{(0)}=' + show(r.V3_0_input) + r'.',
], size: 16.5),
],
),
),


];

// Step 3: PV reactive power & Q-limits (generator-side Qg)
if (includePVStep) {
steps.add(
Step(
isActive: true,
title: Text(step3Title),
content: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
latexLeft([
r'\textbf{Key point: limits are on generator-side }Q_{g}\textbf{, not net }Q.',
r'\vec S_i=\vec S_{Gi}-\vec S_{Di}\Rightarrow Q_i=Q_{gi}-Q_{di}\Rightarrow Q_{gi}=Q_i+Q_{di}.',
r'',
r'\textbf{General PV reactive-power update (Gauss–Seidel)}',
r'Q_{i}^{(k+1)}=-\,\mathrm{Im}\!\left\{(\vec V_{i}^{(k)})^{*}\left[\sum_{j=1}^{i-1}\vec Y_{ij}\vec V_{j}^{(k+1)}+\sum_{j=i}^{n}\vec Y_{ij}\vec V_{j}^{(k)}\right]\right\},\quad i=m+1,\ldots,n.',
], size: 16.3),
const SizedBox(height: 10),

if (r.bus2Type == BusKind.pv) ...[
latexBlock([r'\textbf{PV at Bus 2: Worked example at }k=0\textbf{ (your inputs)}'], size: 16.5),
const SizedBox(height: 6),
latexLeft([
r'\textbf{For 3-bus at bus 2:}',
r'Q_{2,\text{net}}^{(k+1)}=-\,\mathrm{Im}\!\left\{(\vec V_{2}^{(k)})^{*}\Big(\vec Y_{21}\vec V_{1}+\vec Y_{22}\vec V_{2}^{(k)}+\vec Y_{23}\vec V_{3}^{(k)}\Big)\right\}.',
r'',
r'\vec V_1^{(0)}=' + show(r.V1) + r',\quad \vec V_2^{(0)}=' + show(r.V2_0_input) + r',\quad \vec V_3^{(0)}=' + show(r.V3_0_input) + r'.',
r'\vec Y_{21}=' + show(r.Y21) + r',\quad \vec Y_{22}=' + show(r.Y22) + r',\quad \vec Y_{23}=' + show(r.Y23) + r'.',
r'',
r'\textbf{1) Form neighbour terms (at bus 2)}',

// Y21 * V1
r'\vec Y_{21}\vec V_1^{(0)}'
r'=\big(' + rectN(r.Y21, 5) + r'\big)\big(' + rectN(r.V1, 5) + r'\big)'
r'=' + rectN(r.term21, 5) + r'=' + showN(r.term21, 5) + r'.',

// Y22 * V2
r'\vec Y_{22}\vec V_2^{(0)}'
r'=\big(' + rectN(r.Y22, 5) + r'\big)\big(' + rectN(r.V2_0_input, 5) + r'\big)'
r'=' + rectN(r.term22, 5) + r'=' + showN(r.term22, 5) + r'.',

// Y23 * V3
r'\vec Y_{23}\vec V_3^{(0)}'
r'=\big(' + rectN(r.Y23, 5) + r'\big)\big(' + rectN(r.V3_0_input, 5) + r'\big)'
r'=' + rectN(r.term23, 5) + r'=' + showN(r.term23, 5) + r'.',

r'',
r'\textbf{2) Sum neighbours:}',
r'\sum \vec Y_{2j}\vec V_j=\vec Y_{21}\vec V_1^{(0)}+\vec Y_{22}\vec V_2^{(0)}+\vec Y_{23}\vec V_3^{(0)}',
r'\ \ \ \ \ \ \ \ \ \ \ \ \ \ \ \ \ \ =(' +
rectN(r.term21, 5) +
r')+(' +
rectN(r.term22, 5) +
r')+(' +
rectN(r.term23, 5) +
r')',
r'\ \ \ \ \ \ \ \ \ \ \ \ \ \ \ \ \ \ =' + showN(r.sumY2, 5) + r'.',
r'',
r'\textbf{3) Multiply by }(\vec V_2^{(0)})^{*}:',
r'(\vec V_2^{(0)})^{*}=' + show(r.V2_0_input.conj()) + r'.',
r'\Big(\vec Y_{21}\vec V_1^{(0)}+\vec Y_{22}\vec V_2^{(0)}+\vec Y_{23}\vec V_3^{(0)}\Big)=' + showN(r.sumY2, 5) + r'.',
r'(\vec V_2^{(0)})^{*}\Big(\vec Y_{21}\vec V_1^{(0)}+\vec Y_{22}\vec V_2^{(0)}+\vec Y_{23}\vec V_3^{(0)}\Big)',
r'\ \ \ \ \ \ \ \ \ \ \ \ \ \ \ \ \ \ =(' +
rectN(r.V2_0_input.conj(), 5) +
r')(' +
rectN(r.sumY2, 5) +
r')',
r'\ \ \ \ \ \ \ \ \ \ \ \ \ \ \ \ \ \ =' + rectN(prodPV2, 5) + r'=' + showN(prodPV2, 5) + r'.',
r'',
r'\textbf{4) Take the negative imaginary part:}',
r'Q_{2,\text{net}}^{(1)}=-\mathrm{Im}\!\left\{(\vec V_2^{(0)})^{*}\Big(\vec Y_{21}\vec V_1^{(0)}+\vec Y_{22}\vec V_2^{(0)}+\vec Y_{23}\vec V_3^{(0)}\Big)\right\}',
r'\ \ \ \ \ \ \ \ \ \ \ \ \ \ \ \ \ \ =-\mathrm{Im}\{' + rectN(prodPV2, 5) + r'\}=' + sig(r.Q2_net_raw_0, 5) + r'.',
r'',
r'\textbf{5) Convert to generator-side }Q_{g2}:',
r'Q_{g2}^{(1)}=Q_{2,\text{net}}^{(1)}+Q_{d2}=' +
sig(r.Qg2_raw_0, 5) +
r'\quad(\text{since }Q_{2,\text{net}}=Q_{g2}-Q_{d2}).',
r'',
r'\color{red}{\underline{\textbf{6) Check generator Q-limits (if provided)}}}',
r'\text{If }Q_{g2}^{(k+1)}<Q_{g2,\min}\Rightarrow Q_{g2}:=Q_{g2,\min},\qquad '
r'Q_{g2}^{(k+1)}>Q_{g2,\max}\Rightarrow Q_{g2}:=Q_{g2,\max}.',
(r.Q2min == null && r.Q2max == null)
? r'\textbf{No Q-limits were provided, so we do not update.}'
: (r.Qg2_low_viol_0
    ? (r'\textbf{Violation: }Q_{g2}^{(1)}<Q_{g2,\min}\Rightarrow Q_{g2}:=Q_{g2,\min}=' +
        sig(r.Q2min!) +
        r'.')
    : (r.Qg2_high_viol_0
        ? (r'\textbf{Violation: }Q_{g2}^{(1)}>Q_{g2,\max}\Rightarrow Q_{g2}:=Q_{g2,\max}=' +
            sig(r.Q2max!) +
            r'.')
        : r'\textbf{Within limits: }Q_{g2}\text{ unchanged.}')),
r'\textbf{Generator-side Q used: }Q_{g2}=' + sig(r.Qg2_used_0, 5) + r'.',
r'',
r'\textbf{7) Convert back to net }Q_2\text{ for solving:}',
r'Q_{2,\text{net}}=Q_{g2}-Q_{d2}=' + sig(r.Q2_net_used_0, 5) + r'.',
r'',

if (!r.bus2DroppedToPQ_0) ...[
r'\textbf{No violation: enforce PV voltage magnitude}',
r'\text{After computing }\tilde{\vec V}_2^{(k+1)}\text{, set }|\vec V_2^{(k+1)}|:=|\vec V_2|_{\text{spec}}\text{ (keep angle).}',
r'',
],

if (r.bus2DroppedToPQ_0) ...[
r'\textbf{Because of violation: PV }\to\textbf{ PQ and use flat start}',
r'\vec V_2^{(0)}:=1\angle 0^\circ.',
r'',
],

r'\textbf{8) Form net power at bus 2 for Gauss–Seidel update:}',
r'\vec S_2=P_2+jQ_{2,\text{net}}=' + show(r.S2_0) + r',\quad \vec S_2^{*}=' + show(r.S2_0.conj()) + r'.',
], size: 16.1),
const SizedBox(height: 14),
],

if (r.bus3Type == BusKind.pv) ...[
latexBlock([r'\textbf{PV at Bus 3: Worked example at }k=0\textbf{ (your inputs)}'], size: 16.5),
const SizedBox(height: 6),
latexLeft([
r'\textbf{For 3-bus at bus 3:}',
r'Q_{3,\text{net}}^{(k+1)}=-\,\mathrm{Im}\!\left\{(\vec V_{3}^{(k)})^{*}\Big(\vec Y_{31}\vec V_{1}+\vec Y_{32}\vec V_{2}^{(k)}+\vec Y_{33}\vec V_{3}^{(k)}\Big)\right\}.',
r'',
r'\vec V_1^{(0)}=' + show(r.V1) + r',\quad \vec V_2^{(0)}=' + show(r.V2_0_input) + r',\quad \vec V_3^{(0)}=' + show(r.V3_0_input) + r'.',
r'\vec Y_{31}=' + show(r.Y31) + r',\quad \vec Y_{32}=' + show(r.Y32) + r',\quad \vec Y_{33}=' + show(r.Y33) + r'.',
r'',
r'\textbf{1) Form neighbour terms (at bus 3)}',

// Y31 * V1
r'\vec Y_{31}\vec V_1^{(0)}'
r'=\big(' + rectN(r.Y31, 5) + r'\big)\big(' + rectN(r.V1, 5) + r'\big)'
r'=' + rectN(r.term31, 5) + r'=' + showN(r.term31, 5) + r'.',

// Y32 * V2
r'\vec Y_{32}\vec V_2^{(0)}'
r'=\big(' + rectN(r.Y32, 5) + r'\big)\big(' + rectN(r.V2_0_input, 5) + r'\big)'
r'=' + rectN(r.term32, 5) + r'=' + showN(r.term32, 5) + r'.',

// Y33 * V3
r'\vec Y_{33}\vec V_3^{(0)}'
r'=\big(' + rectN(r.Y33, 5) + r'\big)\big(' + rectN(r.V3_0_input, 5) + r'\big)'
r'=' + rectN(r.term33, 5) + r'=' + showN(r.term33, 5) + r'.',

r'',
r'\textbf{2) Sum neighbours:}',
r'\sum \vec Y_{3j}\vec V_j=\vec Y_{31}\vec V_1^{(0)}+\vec Y_{32}\vec V_2^{(0)}+\vec Y_{33}\vec V_3^{(0)}',
r'\ \ \ \ \ \ \ \ \ \ \ \ \ \ \ \ \ \ =(' +
rectN(r.term31, 5) +
r')+(' +
rectN(r.term32, 5) +
r')+(' +
rectN(r.term33, 5) +
r')',
r'\ \ \ \ \ \ \ \ \ \ \ \ \ \ \ \ \ \ =' + showN(r.sumY3, 5) + r'.',
r'',
r'\textbf{3) Multiply by }(\vec V_3^{(0)})^{*}:',
r'(\vec V_3^{(0)})^{*}=' + show(r.V3_0_input.conj()) + r'.',
r'\Big(\vec Y_{31}\vec V_1^{(0)}+\vec Y_{32}\vec V_2^{(0)}+\vec Y_{33}\vec V_3^{(0)}\Big)=' + showN(r.sumY3, 5) + r'.',
r'(\vec V_3^{(0)})^{*}\Big(\vec Y_{31}\vec V_1^{(0)}+\vec Y_{32}\vec V_2^{(0)}+\vec Y_{33}\vec V_3^{(0)}\Big)',
r'\ \ \ \ \ \ \ \ \ \ \ \ \ \ \ \ \ \ =(' +
rectN(r.V3_0_input.conj(), 5) +
r')(' +
rectN(r.sumY3, 5) +
r')',
r'\ \ \ \ \ \ \ \ \ \ \ \ \ \ \ \ \ \ =' + rectN(prodPV3, 5) + r'=' + showN(prodPV3, 5) + r'.',
r'',
r'\textbf{4) Take the negative imaginary part:}',
r'Q_{3,\text{net}}^{(1)}=-\mathrm{Im}\!\left\{(\vec V_3^{(0)})^{*}\Big(\vec Y_{31}\vec V_1^{(0)}+\vec Y_{32}\vec V_2^{(0)}+\vec Y_{33}\vec V_3^{(0)}\Big)\right\}',
r'\ \ \ \ \ \ \ \ \ \ \ \ \ \ \ \ \ \ =-\mathrm{Im}\{' + rectN(prodPV3, 5) + r'\}=' + sig(r.Q3_net_raw_0, 5) + r'.',
r'',
r'\textbf{5) Convert to generator-side }Q_{g3}:',
r'Q_{g3}^{(1)}=Q_{3,\text{net}}^{(1)}+Q_{d3}=' + sig(r.Qg3_raw_0, 5) + r'.',
r'',
r'\color{red}{\underline{\textbf{6) Check generator Q-limits (if provided)}}}',
r'\text{If }Q_{g3}^{(k+1)}<Q_{g3,\min}\Rightarrow Q_{g3}:=Q_{g3,\min},\qquad '
r'Q_{g3}^{(k+1)}>Q_{g3,\max}\Rightarrow Q_{g3}:=Q_{g3,\max}.',
(r.Q3min == null && r.Q3max == null)
? r'\textbf{No Q-limits were provided, so we do not update.}'
: (r.Qg3_low_viol_0
    ? (r'\textbf{Violation: }Q_{g3}^{(1)}<Q_{g3,\min}\Rightarrow Q_{g3}:=Q_{g3,\min}=' + sig(r.Q3min!) + r'.')
    : (r.Qg3_high_viol_0
        ? (r'\textbf{Violation: }Q_{g3}^{(1)}>Q_{g3,\max}\Rightarrow Q_{g3}:=Q_{g3,\max}=' + sig(r.Q3max!) + r'.')
        : r'\textbf{Within limits: }Q_{g3}\text{ unchanged.}')),
r'\textbf{Generator-side Q used: }Q_{g3}=' + sig(r.Qg3_used_0, 5) + r'.',
r'',
r'\textbf{7) Convert back to net }Q_3\text{ for solving:}',
r'Q_{3,\text{net}}=Q_{g3}-Q_{d3}=' + sig(r.Q3_net_used_0, 5) + r'.',
r'',

if (!r.bus3DroppedToPQ_0) ...[
r'\textbf{No violation: enforce PV voltage magnitude}',
r'\text{After computing }\tilde{\vec V}_3^{(k+1)}\text{, set }|\vec V_3^{(k+1)}|:=|\vec V_3|_{\text{spec}}\text{ (keep angle).}',
r'',
],

if (r.bus3DroppedToPQ_0) ...[
r'\textbf{Because of violation: PV }\to\textbf{ PQ and use flat start}',
r'\vec V_3^{(0)}:=1\angle 0^\circ.',
r'',
],

r'\textbf{8) Form net power at bus 3 for Gauss–Seidel update:}',
r'\vec S_3=P_3+jQ_{3,\text{net}}=' + show(r.S3_0) + r',\quad \vec S_3^{*}=' + show(r.S3_0.conj()) + r'.',
], size: 16.1),
],
],
),
),
);
}

// Step 4: GS updates (k=0 -> 1 shown)
steps.add(
Step(
isActive: true,
title: Text(step4Title),
content: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
latexLeft(
[
r'\textbf{Goal: update Bus 2 and Bus 3 voltages using the Gauss\text{–}Seidel equations.}',
r'\text{Flow in this step: }\textbf{formula}\rightarrow\textbf{substitute }k=0\rightarrow\textbf{compute rhs}\rightarrow\textbf{divide by }Y_{ii}\rightarrow\textbf{(if PV) enforce }|V_i|.',
],
size: 17,
),
const SizedBox(height: 12),

latexLeft(
[
r'\textbf{Gauss\text{–}Seidel (general PQ at bus }i\textbf{):}',
r'\vec V_i^{(k+1)}=\frac{1}{\vec Y_{ii}}\left['
r'\frac{\vec S_i^{*}}{\left(\vec V_i^{*}\right)^{(k)}}'
r'-\sum_{j=1}^{i-1}\vec Y_{ij}\vec V_j^{(k+1)}'
r'-\sum_{j=i+1}^{n}\vec Y_{ij}\vec V_j^{(k)}'
r'\right].',
r'',
r'\textbf{For 3-bus (update order 2 then 3):}',
r'\vec V_2^{(k+1)}=\frac{1}{\vec Y_{22}}\left['
r'\frac{\vec S_2^{*}}{\left(\vec V_2^{*}\right)^{(k)}}'
r'-\vec Y_{21}\vec V_1'
r'-\vec Y_{23}\vec V_3^{(k)}'
r'\right].',
r'\text{(enforce }|\vec V_2|\text{ if PV and no violation)}',
r'',
r'\vec V_3^{(k+1)}=\frac{1}{\vec Y_{33}}\left['
r'\frac{\vec S_3^{*}}{\left(\vec V_3^{*}\right)^{(k)}}'
r'-\vec Y_{31}\vec V_1'
r'-\vec Y_{32}\vec V_2^{(k+1)}'
r'\right].',
r'\text{(enforce }|\vec V_3|\text{ if PV and no violation)}',
],
size: 18.5,
),

const SizedBox(height: 14),

// Given at k=0 (before update)
latexBlock(
[r'\textbf{Given at }k=0\textbf{ (used for GS after PV checks)}'],
size: 16.8,
),
const SizedBox(height: 6),

latexLeft(
[
r'\vec V_1^{(0)}=' + show(r.V1) +
r',\quad \vec V_2^{(0)}=' + show(r.V2_0_forGS) +
r',\quad \vec V_3^{(0)}=' + show(r.V3_0_forGS) + r'.',
r'(\vec V_2^{*})^{(0)}=(\vec V_2^{(0)})^{*}=' + show(r.V2_0_forGS.conj()) +
r',\quad (\vec V_3^{*})^{(0)}=(\vec V_3^{(0)})^{*}=' + show(r.V3_0_forGS.conj()) + r'.',
r'\vec Y_{21}=' + show(r.Y21) + r',\ \vec Y_{22}=' + show(r.Y22) + r',\ \vec Y_{23}=' + show(r.Y23) + r'.',
r'\vec Y_{31}=' + show(r.Y31) + r',\ \vec Y_{32}=' + show(r.Y32) + r',\ \vec Y_{33}=' + show(r.Y33) + r'.',
r'',
if (r.bus2Type == BusKind.pv)
r'\textbf{(Bus 2 PV)}\ \vec S_2\text{ uses }Q_{2,\text{net}}\text{ after limit check: }\vec S_2=' + show(r.S2_0) + r'.'
else
r'\vec S_2=' + show(r.S2spec) + r'.',
if (r.bus3Type == BusKind.pv)
r'\textbf{(Bus 3 PV)}\ \vec S_3\text{ uses }Q_{3,\text{net}}\text{ after limit check: }\vec S_3=' + show(r.S3_0) + r'.'
else
r'\vec S_3=' + show(r.S3spec) + r'.',
if (r.bus2Type == BusKind.pv)
r'\vec S_2^{*}=' + show(r.S2_0.conj()) + r'.'
else
r'\vec S_2^{*}=' + show(r.S2spec.conj()) + r'.',

if (r.bus3Type == BusKind.pv)
r'\vec S_3^{*}=' + show(r.S3_0.conj()) + r'.'
else
r'\vec S_3^{*}=' + show(r.S3spec.conj()) + r'.',
r'',
if (r.bus2Type == BusKind.pv && r.bus2DroppedToPQ_0)
r'\textbf{Violation note (Bus 2): } \text{PV}\rightarrow\text{PQ at }k=0,\ \text{so we will NOT enforce }|V_2|\text{ after the raw update.}',
if (r.bus3Type == BusKind.pv && r.bus3DroppedToPQ_0)
r'\textbf{Violation note (Bus 3): } \text{PV}\rightarrow\text{PQ at }k=0,\ \text{so we will NOT enforce }|V_3|\text{ after the raw update.}',
],
size: 16.4,
),

const SizedBox(height: 14),

// Iteration 1 (k=0) for Bus 2
latexBlock(
[r'\textcolor{red}{\textbf{Iteration 1 (}k=0\textbf{): Update }\vec V_2}'],
size: 17.2,
),
const SizedBox(height: 6),

latexLeft(
[
r'\textbf{Start from: }\ \vec V_2^{(1)}=\dfrac{1}{\vec Y_{22}}\left[\dfrac{\vec S_2^{*}}{\left(\vec V_2^{*}\right)^{(0)}}-\vec Y_{21}\vec V_1-\vec Y_{23}\vec V_3^{(0)}\right].',
r'',

// 1) power term 
r'1)\ \textbf{Compute the power term: }\ \dfrac{\vec S_2^{*}}{\left(\vec V_2^{*}\right)^{(0)}}'
r'=\dfrac{'
+ (r.bus2Type == BusKind.pv ? polar(r.S2_0.conj()) : polar(r.S2spec.conj()))
+ r'}{'
+ polar(r.V2_0_forGS.conj())
+ r'}'
r'=' + polar(r.partS2overV2) + r'.',

// 2) neighbour terms 
r'2)\ \textbf{Compute neighbour terms: }',
r'\vec Y_{21}\vec V_1'
r'=(' + polar(r.Y21) + r')(' + polar(r.V1) + r')'
r'=' + polar(term21_gs0) + r'.',
r'\vec Y_{23}\vec V_3^{(0)}'
r'=(' + polar(r.Y23) + r')(' + polar(r.V3_0_forGS) + r')'
r'=' + polar(term23_gs0) + r'.',

// 3) rhs bracket 
r'3)\ \textbf{Form the bracket (rhs): }\ \text{rhs}_2'
r'=\dfrac{\vec S_2^{*}}{\left(\vec V_2^{*}\right)^{(0)}}-\vec Y_{21}\vec V_1-\vec Y_{23}\vec V_3^{(0)}'
r'=(' + polar(r.partS2overV2) + r')-(' + polar(term21_gs0) + r')-(' + polar(term23_gs0) + r')'
r'=' + polar(r.rhsV2) + r'.',

// 4) divide by Y22 
r'4)\ \textbf{Divide by }\vec Y_{22}\textbf{: }\ \vec V_{2,\text{raw}}^{(1)}'
r'=\dfrac{\text{rhs}_2}{\vec Y_{22}}'
r'=\dfrac{' + polar(r.rhsV2) + r'}{' + polar(r.Y22) + r'}'
r'=' + show(r.V2newRaw) + r'.',

r'',

// 5) PV/PQ handling
if (r.bus2Type == BusKind.pv && !r.bus2DroppedToPQ_0) ...[
r'\textbf{5) PV enforcement (keep angle, fix magnitude):}',
r'\Rightarrow\ \vec V_2^{(1)}=' + show(r.V2new) + r'.',
] else if (r.bus2Type == BusKind.pv && r.bus2DroppedToPQ_0) ...[
r'\textbf{5) PV}\rightarrow\textbf{PQ (violation): no magnitude enforcement.}',
r'\Rightarrow\ \vec V_2^{(1)}=\vec V_{2,\text{raw}}^{(1)}=' + show(r.V2newRaw) + r'.',
] else ...[
r'\textbf{5) PQ bus: no magnitude enforcement.}',
r'\Rightarrow\ \vec V_2^{(1)}=\vec V_{2,\text{raw}}^{(1)}=' + show(r.V2newRaw) + r'.',
],
],
size: 16.6,
),

const SizedBox(height: 14),


// Iteration 1 (k=0) for Bus 3
latexBlock(
[r'\textcolor{red}{\textbf{Iteration 1 (}k=0\textbf{): Update }\vec V_3}'],
size: 17.2,
),
const SizedBox(height: 6),

latexLeft(
[
r'\textbf{Start from: }\ \vec V_3^{(1)}=\dfrac{1}{\vec Y_{33}}\left[\dfrac{\vec S_3^{*}}{\left(\vec V_3^{*}\right)^{(0)}}-\vec Y_{31}\vec V_1-\vec Y_{32}\vec V_2^{(1)}\right].',
r'',

// 1) power term 
r'1)\ \textbf{Compute the power term: }\ \dfrac{\vec S_3^{*}}{\left(\vec V_3^{*}\right)^{(0)}}'
r'=\dfrac{'
+ (r.bus3Type == BusKind.pv ? polar(r.S3_0.conj()) : polar(r.S3spec.conj()))
+ r'}{'
+ polar(r.V3_0_forGS.conj())
+ r'}'
r'=' + polar(r.partS3overV3) + r'.',

// 2) neighbour terms
r'2)\ \textbf{Compute neighbour terms: }',
r'\vec Y_{31}\vec V_1'
r'=(' + polar(r.Y31) + r')(' + polar(r.V1) + r')'
r'=' + polar(term31_gs0) + r'.',
r'\vec Y_{32}\vec V_2^{(1)}'
r'=(' + polar(r.Y32) + r')(' + polar(r.V2new) + r')'
r'=' + polar(term32_gs1) + r'.',

// 3) rhs bracket 
r'3)\ \textbf{Form the bracket (rhs): }\ \text{rhs}_3'
r'=\dfrac{\vec S_3^{*}}{\left(\vec V_3^{*}\right)^{(0)}}-\vec Y_{31}\vec V_1-\vec Y_{32}\vec V_2^{(1)}'
r'=(' + polar(r.partS3overV3) + r')-(' + polar(term31_gs0) + r')-(' + polar(term32_gs1) + r')'
r'=' + polar(r.rhsV3) + r'.',

// 4) divide by Y33 
r'4)\ \textbf{Divide by }\vec Y_{33}\textbf{: }\ \vec V_{3,\text{raw}}^{(1)}'
r'=\dfrac{\text{rhs}_3}{\vec Y_{33}}'
r'=\dfrac{' + polar(r.rhsV3) + r'}{' + polar(r.Y33) + r'}'
r'=' + show(r.V3newRaw) + r'.',

r'',

// 5) PV/PQ handling
if (r.bus3Type == BusKind.pv && !r.bus3DroppedToPQ_0) ...[
r'\textbf{5) PV enforcement (keep angle, fix magnitude):}',
r'\Rightarrow\ \vec V_3^{(1)}=' + show(r.V3new) + r'.',
] else if (r.bus3Type == BusKind.pv && r.bus3DroppedToPQ_0) ...[
r'\textbf{5) PV}\rightarrow\textbf{PQ (violation): no magnitude enforcement.}',
r'\Rightarrow\ \vec V_3^{(1)}=\vec V_{3,\text{raw}}^{(1)}=' + show(r.V3newRaw) + r'.',
] else ...[
r'\textbf{5) PQ bus: no magnitude enforcement.}',
r'\Rightarrow\ \vec V_3^{(1)}=\vec V_{3,\text{raw}}^{(1)}=' + show(r.V3newRaw) + r'.',
],
],
size: 16.6,
),
],
),
),
);





// Step 5: iteration table (convergence) OR fixed-iteration workings
steps.add(
Step(
isActive: true,
title: Text(step5Title),
content: r.iterate ? _iterTable(r) : _fixedIterationsWork(r, show, rect),
),
);


// Step 6: slack bus real and reactive power 
steps.add(
Step(
isActive: true,
title: Text(step6Title),
content: Column(
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
r'\text{For 3-bus: }\ \vec I_1=\vec Y_{11}\vec V_1+\vec Y_{12}\vec V_2^{(\text{final})}+\vec Y_{13}\vec V_3^{(\text{final})}.',
r'',

r'\textbf{Step 2: compute slack injected power}',
r'\vec S_1=\vec V_1\,\vec I_1^{*}\;=\;P_1+jQ_1.',
r'',

r'\textbf{Given (final converged voltages)}',
r'\vec V_1=' + show(r.V1) + r',\ \vec V_2^{(\text{final})}=' + show(r.V2final) + r',\ \vec V_3^{(\text{final})}=' + show(r.V3final) + r'.',
r'\vec Y_{11}=' + show(r.Y11) + r',\ \vec Y_{12}=' + show(r.Y12) + r',\ \vec Y_{13}=' + show(r.Y13) + r'.',
r'',

r'\textbf{Substitute values}',
r'1)\ \vec I_{11}=\vec Y_{11}\vec V_1'
r'=\big(' + rect(r.Y11) + r'\big)\big(' + rect(r.V1) + r'\big)'
r'=' + show(I11_term) + r'.',
r'2)\ \vec I_{12}=\vec Y_{12}\vec V_2^{(\text{final})}'
r'=\big(' + rect(r.Y12) + r'\big)\big(' + rect(r.V2final) + r'\big)'
r'=' + show(I12_term) + r'.',
r'3)\ \vec I_{13}=\vec Y_{13}\vec V_3^{(\text{final})}'
r'=\big(' + rect(r.Y13) + r'\big)\big(' + rect(r.V3final) + r'\big)'
r'=' + show(I13_term) + r'.',
r'4)\ \vec I_1=\vec I_{11}+\vec I_{12}+\vec I_{13}=' + show(I1_sum) + r'.',
r'5)\ \vec I_1^{*}=' + show(I1_star) + r'.',
r'6)\ \vec S_1=\vec V_1\,\vec I_1^{*}'
r'=\big(' + rect(r.V1) + r'\big)\big(' + rect(I1_star) + r'\big)'
r'=' + show(S1_calc) + r'.',
r'',
r'\textbf{Extract real and reactive power}',
r'P_1=\mathrm{Re}(\vec S_1)=' + sig(P1_pu) + r'\ \text{pu},\ '
r'Q_1=\mathrm{Im}(\vec S_1)=' + sig(Q1_pu) + r'\ \text{pu}.',

r'\textbf{Convert to actual (using }S_{\text{base}}\textbf{)}',

r'S_{\text{base}}=' + sig(r.sBaseMVA) + r'\ \text{MVA}.',

r'P_1=' + sig(P1_pu) + r'\times ' + sig(r.sBaseMVA) +
r'=' + sig(P1_MW) + r'\ \text{MW}.',

r'Q_1=' + sig(Q1_pu) + r'\times ' + sig(r.sBaseMVA) +
r'=' + sig(Q1_Mvar) + r'\ \text{Mvar}.',

], size: 16.5),

const SizedBox(height: 10),

// Work backwards from S1 to find missing generator or load power at Bus 1 (if not given)
softBox(
latexLeft([
if (r.slackGiven == SlackGiven.sd1Given) ...[
r'\textbf{Exam Question gives }\vec S_{d1}\textbf{ and need to find }\vec S_{g1}\textbf{:}\\'
r'\textbf{ }\vec S_{d1}\ \textbf{given}',
r'',
r'\vec S_1=' + show(S1_calc) + r'.',
r'\vec S_{d1}=' + show(r.Sd1_final) + r'.',
r'',
r'\text{Use }\vec S_1=\vec S_{g1}-\vec S_{d1}\Rightarrow \vec S_{g1}=\vec S_1+\vec S_{d1}.',
r'',
r'\vec S_{g1}'
r'=\big(' + rect(S1_calc) + r'\big)+\big(' + rect(r.Sd1_final) + r'\big)',
r'\vec S_{g1}=' + show(r.Sg1_final) + r'.',
] else if (r.slackGiven == SlackGiven.sg1Given) ...[
r'\textbf{Exam Question gives }\vec S_{g1}\textbf{ and need to find }\vec S_{d1}\textbf{:}\\'
r'\textbf{ }\vec S_{g1}\ \textbf{given}',
r'',
r'\vec S_1=' + show(S1_calc) + r'.',
r'\vec S_{g1}=' + show(r.Sg1_final) + r'.',
r'',
r'\text{Use }\vec S_1=\vec S_{g1}-\vec S_{d1}\Rightarrow \vec S_{d1}=\vec S_{g1}-\vec S_1.',
r'',
r'\vec S_{d1}'
r'=\big(' + rect(r.Sg1_final) + r'\big)-\big(' + rect(S1_calc) + r'\big)',
r'\vec S_{d1}=' + show(r.Sd1_final) + r'.',
] else ...[
r'\textbf{Sometimes Exam would give }\vec S_{d1}\textbf{ or }\vec S_{g1}\textbf{ and ask for the other (work backwards):}',
r'\text{If }\vec S_{d1}\text{ is given: }\ \vec S_{g1}=\vec S_1+\vec S_{d1}.',
r'\text{If }\vec S_{g1}\text{ is given: }\ \vec S_{d1}=\vec S_{g1}-\vec S_1.',
],
], size: 16),
),
],
),
),
);

// Step 7: line flows and line losses  
steps.add(
Step(
isActive: true,
title: Text(step7Title),
content: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
latexLeft([
r'\textbf{Goal: compute line power flows and total system losses (no shunt / no line charging).}',
r'\text{We will compute branch currents }\ \vec I_{ij}\ \text{and complex power flows }\ \vec S_{ij}\ \text{at both ends of each line.}',
r'',
r'\textbf{Branch current equations}',
r'\vec I_{ij}=\underbrace{\vec y_{ij}(\vec V_i-\vec V_j)}_{\text{series current}}.',
r'',
r'\text{So for each branch:}',
r'\begin{aligned}'
r'\vec I_{12}&=\underbrace{\vec y_{12}(\vec V_1-\vec V_2)}_{\text{series current}},'
r'&\qquad \vec I_{21}&=\underbrace{\vec y_{12}(\vec V_2-\vec V_1)}_{\text{series current}}.\\'
r'\vec I_{13}&=\underbrace{\vec y_{13}(\vec V_1-\vec V_3)}_{\text{series current}},'
r'&\qquad \vec I_{31}&=\underbrace{\vec y_{13}(\vec V_3-\vec V_1)}_{\text{series current}}.\\'
r'\vec I_{23}&=\underbrace{\vec y_{23}(\vec V_2-\vec V_3)}_{\text{series current}},'
r'&\qquad \vec I_{32}&=\underbrace{\vec y_{23}(\vec V_3-\vec V_2)}_{\text{series current}}.'
r'\end{aligned}',
r'',



r'\textbf{Complex power flow definition}',
r'\vec S=\vec V\,\vec I^{*}\quad \Rightarrow\quad \vec S_{ij}=\vec V_i\,\vec I_{ij}^{*}.',
r'\textbf{Line loss: }\ \vec S_{\text{loss},ij}=\vec S_{ij}+\vec S_{ji}.',
r'',

r'\textbf{Substitute final values}',
r'\vec V_1=' + show(r.V1) + r',\quad \vec V_2^{(\text{final})}=' + show(r.V2final) + r',\quad \vec V_3^{(\text{final})}=' + show(r.V3final) + r'.',
r'\vec y_{12}=' + show(r.y12) + r',\quad \vec y_{13}=' + show(r.y13) + r',\quad \vec y_{23}=' + show(r.y23) + r'.',
r'',

// Line 1–2
r'\underline{\textbf{Line 1–2: compute }\vec I_{12},\ \vec I_{21}\ \textbf{and }\vec S_{\text{loss},12}}',
r'',

r'\underline{\textbf{Compute }\vec I_{12}\textbf{ (Bus 1 }\rightarrow\textbf{ Bus 2)}}',
r'1)\ \Delta \vec V_{12}=\vec V_1-\vec V_2^{(\text{final})}'
r'=\big(' + rect(r.V1) + r'\big)-\big(' + rect(r.V2final) + r'\big)'
r'=' + rect(V12) + r'=' + polar(V12) + r'.',
r'2)\ \vec I_{12}=\vec y_{12}\Delta \vec V_{12}'
r'=\big(' + rect(r.y12) + r'\big)\big(' + rect(V12) + r'\big)'
r'=' + rect(I12_calc) + r'=' + polar(I12_calc) + r'.',
r'3)\ \vec I_{12}^{*}=' + show(I12_star) + r'.',
r'4)\ \vec S_{12}=\vec V_1\vec I_{12}^{*}'
r'=\big(' + rect(r.V1) + r'\big)\big(' + rect(I12_star) + r'\big)'
r'=' + show(S12_calc) + r'.',
r'',

r'\underline{\textbf{Compute }\vec I_{21}\textbf{ (Bus 2 }\rightarrow\textbf{ Bus 1)}}',
r'1)\ \Delta \vec V_{21}=\vec V_2^{(\text{final})}-\vec V_1'
r'=\big(' + rect(r.V2final) + r'\big)-\big(' + rect(r.V1) + r'\big)'
r'=' + rect(V21) + r'=' + polar(V21) + r'.',
r'2)\ \vec I_{21}=\vec y_{12}\Delta \vec V_{21}'
r'=\big(' + rect(r.y12) + r'\big)\big(' + rect(V21) + r'\big)'
r'=' + rect(I21_calc) + r'=' + polar(I21_calc) + r'.',
r'3)\ \vec I_{21}^{*}=' + show(I21_star) + r'.',
r'4)\ \vec S_{21}=\vec V_2^{(\text{final})}\vec I_{21}^{*}'
r'=\big(' + rect(r.V2final) + r'\big)\big(' + rect(I21_star) + r'\big)'
r'=' + show(S21_calc) + r'.',
r'',

r'\underline{\textbf{Line losses (per line, power balance)}}',
r'\vec S_{\text{loss},12}=\vec S_{12}+\vec S_{21}=' + show(Sloss12_calc) + r'.',
r'P_{\text{loss},12}\ \text{(pu)}=\mathrm{Re}(\vec S_{\text{loss},12})=' + sig(Sloss12_calc.re) + r'.',
r'Q_{\text{loss},12}\ \text{(pu)}=\mathrm{Im}(\vec S_{\text{loss},12})=' + sig(Sloss12_calc.im) + r'.',
r'',
r'',

// Line 1–3
r'\underline{\textbf{Line 1–3: compute }\vec I_{13},\ \vec I_{31}\ \textbf{and }\vec S_{\text{loss},13}}',
r'',

r'\underline{\textbf{Compute }\vec I_{13}\textbf{ (Bus 1 }\rightarrow\textbf{ Bus 3)}}',
r'1)\ \Delta \vec V_{13}=\vec V_1-\vec V_3^{(\text{final})}'
r'=\big(' + rect(r.V1) + r'\big)-\big(' + rect(r.V3final) + r'\big)'
r'=' + rect(V13) + r'=' + polar(V13) + r'.',
r'2)\ \vec I_{13}=\vec y_{13}\Delta \vec V_{13}'
r'=\big(' + rect(r.y13) + r'\big)\big(' + rect(V13) + r'\big)'
r'=' + rect(I13_calc) + r'=' + polar(I13_calc) + r'.',
r'3)\ \vec I_{13}^{*}=' + show(I13_star) + r'.',
r'4)\ \vec S_{13}=\vec V_1\vec I_{13}^{*}'
r'=\big(' + rect(r.V1) + r'\big)\big(' + rect(I13_star) + r'\big)'
r'=' + show(S13_calc) + r'.',
r'',

r'\underline{\textbf{Compute }\vec I_{31}\textbf{ (Bus 3 }\rightarrow\textbf{ Bus 1)}}',
r'1)\ \Delta \vec V_{31}=\vec V_3^{(\text{final})}-\vec V_1'
r'=\big(' + rect(r.V3final) + r'\big)-\big(' + rect(r.V1) + r'\big)'
r'=' + rect(V31) + r'=' + polar(V31) + r'.',
r'2)\ \vec I_{31}=\vec y_{13}\Delta \vec V_{31}'
r'=\big(' + rect(r.y13) + r'\big)\big(' + rect(V31) + r'\big)'
r'=' + rect(I31_calc) + r'=' + polar(I31_calc) + r'.',
r'3)\ \vec I_{31}^{*}=' + show(I31_star) + r'.',
r'4)\ \vec S_{31}=\vec V_3^{(\text{final})}\vec I_{31}^{*}'
r'=\big(' + rect(r.V3final) + r'\big)\big(' + rect(I31_star) + r'\big)'
r'=' + show(S31_calc) + r'.',
r'',

r'\underline{\textbf{Line losses (per line, power balance)}}',
r'\vec S_{\text{loss},13}=\vec S_{13}+\vec S_{31}=' + show(Sloss13_calc) + r'.',
r'P_{\text{loss},13}\ \text{(pu)}=\mathrm{Re}(\vec S_{\text{loss},13})=' + sig(Sloss13_calc.re) + r'.',
r'Q_{\text{loss},13}\ \text{(pu)}=\mathrm{Im}(\vec S_{\text{loss},13})=' + sig(Sloss13_calc.im) + r'.',
r'',
r'',

// Line 2–3
r'\underline{\textbf{Line 2–3: compute }\vec I_{23},\ \vec I_{32}\ \textbf{and }\vec S_{\text{loss},23}}',
r'',

r'\underline{\textbf{Compute }\vec I_{23}\textbf{ (Bus 2 }\rightarrow\textbf{ Bus 3)}}',
r'1)\ \Delta \vec V_{23}=\vec V_2^{(\text{final})}-\vec V_3^{(\text{final})}'
r'=\big(' + rect(r.V2final) + r'\big)-\big(' + rect(r.V3final) + r'\big)'
r'=' + rect(V23) + r'=' + polar(V23) + r'.',
r'2)\ \vec I_{23}=\vec y_{23}\Delta \vec V_{23}'
r'=\big(' + rect(r.y23) + r'\big)\big(' + rect(V23) + r'\big)'
r'=' + rect(I23_calc) + r'=' + polar(I23_calc) + r'.',
r'3)\ \vec I_{23}^{*}=' + show(I23_star) + r'.',
r'4)\ \vec S_{23}=\vec V_2^{(\text{final})}\vec I_{23}^{*}'
r'=\big(' + rect(r.V2final) + r'\big)\big(' + rect(I23_star) + r'\big)'
r'=' + show(S23_calc) + r'.',
r'',

r'\underline{\textbf{Compute }\vec I_{32}\textbf{ (Bus 3 }\rightarrow\textbf{ Bus 2)}}',
r'1)\ \Delta \vec V_{32}=\vec V_3^{(\text{final})}-\vec V_2^{(\text{final})}'
r'=\big(' + rect(r.V3final) + r'\big)-\big(' + rect(r.V2final) + r'\big)'
r'=' + rect(V32) + r'=' + polar(V32) + r'.',
r'2)\ \vec I_{32}=\vec y_{23}\Delta \vec V_{32}'
r'=\big(' + rect(r.y23) + r'\big)\big(' + rect(V32) + r'\big)'
r'=' + rect(I32_calc) + r'=' + polar(I32_calc) + r'.',
r'3)\ \vec I_{32}^{*}=' + show(I32_star) + r'.',
r'4)\ \vec S_{32}=\vec V_3^{(\text{final})}\vec I_{32}^{*}'
r'=\big(' + rect(r.V3final) + r'\big)\big(' + rect(I32_star) + r'\big)'
r'=' + show(S32_calc) + r'.',
r'',

r'\underline{\textbf{Line losses (per line, power balance)}}',
r'\vec S_{\text{loss},23}=\vec S_{23}+\vec S_{32}=' + show(Sloss23_calc) + r'.',
r'P_{\text{loss},23}\ \text{(pu)}=\mathrm{Re}(\vec S_{\text{loss},23})=' + sig(Sloss23_calc.re) + r'.',
r'Q_{\text{loss},23}\ \text{(pu)}=\mathrm{Im}(\vec S_{\text{loss},23})=' + sig(Sloss23_calc.im) + r'.',
r'',
r'',

// Total losses 
r'\underline{\textbf{Total system losses}}',
r'\vec S_{\text{loss,total}}=\vec S_{\text{loss},12}+\vec S_{\text{loss},13}+\vec S_{\text{loss},23}=' + show(SlossTotal_calc) + r'.',
r'P_{\text{loss}}\ \text{per unit (pu)}=\mathrm{Re}(\vec S_{\text{loss,total}})=' +
sig(SlossTotal_calc.re) +
r',\quad Q_{\text{loss}}\ \text{per unit (pu)}=\mathrm{Im}(\vec S_{\text{loss,total}})=' +
sig(SlossTotal_calc.im) +
r'.',
r'P_{\text{loss,actual}}=P_{\text{loss per unit}}\;S_{\text{base}}=' +
sig(SlossTotal_calc.re * r.sBaseMVA) +
r'\ \text{MW}.',
r'Q_{\text{loss,actual}}=Q_{\text{loss per unit}}\;S_{\text{base}}=' +
sig(SlossTotal_calc.im * r.sBaseMVA) +
r'\ \text{Mvar}\quad (S_{\text{base}}=' +
sig(r.sBaseMVA) +
r'\ \text{MVA}).',
], size: 16.5),
],
),
),
);



return _buildStepsUI(steps);

}

Widget _buildStepsUI(List<Step> steps) {
final theme = Theme.of(context);

Widget topButtons() => Row(
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

Widget stepHeader(int i, Step s) {
return InkWell(
onTap: () => setState(() {
_openStep = (_openStep == i) ? -1 : i;
_showAllWorkings = false;
}),
child: Padding(
padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
child: Row(
crossAxisAlignment: CrossAxisAlignment.center,
children: [
CircleAvatar(
radius: 14,
backgroundColor: theme.colorScheme.primary.withOpacity(0.12),
child: Text(
'${i + 1}',
style: TextStyle(
fontSize: 12,
fontWeight: FontWeight.w700,
color: theme.colorScheme.primary,
),
),
),
const SizedBox(width: 10),
Expanded(
child: DefaultTextStyle.merge(
style: _stepHeaderStyle,
child: s.title,
),
),
Icon(
(_openStep == i) ? Icons.expand_less : Icons.expand_more,
color: Colors.grey.shade600,
),
],
),
),
);
}

// show all workings
if (_showAllWorkings) {
return Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
topButtons(),
const SizedBox(height: 12),
...List.generate(steps.length, (i) {
final s = steps[i];
return Padding(
padding: const EdgeInsets.only(bottom: 14),
child: Card(
elevation: 0.2,
child: Padding(
padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
  Row(
    children: [
      CircleAvatar(
        radius: 14,
        backgroundColor: theme.colorScheme.primary.withOpacity(0.12),
        child: Text(
          '${i + 1}',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: theme.colorScheme.primary,
          ),
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: DefaultTextStyle.merge(
          style: _stepHeaderStyle,
          child: s.title,
        ),
      ),
    ],
  ),
  const SizedBox(height: 12),
  s.content,
],
),
),
),
);
}),
],
);
}

return Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
topButtons(),
const SizedBox(height: 12),
...List.generate(steps.length, (i) {
final s = steps[i];
final isOpen = (_openStep == i);

return Card(
elevation: 0.2,
margin: const EdgeInsets.symmetric(vertical: 6),
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
stepHeader(i, s),

if (isOpen) ...[
const Divider(height: 1),
Padding(
padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
child: s.content,
),
Padding(
padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
child: Row(
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
        if (_openStep > 0) {
          _openStep--;
        } else {
          _openStep = -1; 
        }
      }),
      child: const Text('Cancel'),
    ),
  ],
),
),
],
],
),
);
}),
],
);
}




Widget _iterTable(GS3Result r) {
// table formatter 
String s(double v, [int k = 5]) => sig(v, k);

// final-line formatter 
String f(double v, [int dp = 4]) => v.toStringAsFixed(dp);

return Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
const SizedBox(height: 6),
Text(
r.converged
? 'Converged in ${r.rows.length} iteration(s).'
: 'Stopped at ${r.rows.length} iteration(s) (max).',
style: TextStyle(
fontWeight: FontWeight.w600,
color: r.converged ? Colors.green[800] : Colors.orange[800],
),
),
const SizedBox(height: 10),
SingleChildScrollView(
scrollDirection: Axis.horizontal,
child: DataTable(
columns: const [
DataColumn(label: Text('k')),
DataColumn(label: Text('V2 (rect)')),
DataColumn(label: Text('V2 (polar)')),
DataColumn(label: Text('|ΔV2|')),
DataColumn(label: Text('V3 (rect)')),
DataColumn(label: Text('V3 (polar)')),
DataColumn(label: Text('|ΔV3|')),
],
rows: r.rows
.map(
(row) => DataRow(
cells: [
  DataCell(Text('${row.k}')),
  DataCell(Text(
      '${s(row.V2.re)} ${row.V2.im >= 0 ? '+' : '-'} j${s(row.V2.im.abs())}')),
  DataCell(Text('${s(row.V2.abs())}∠${s(row.V2.angDeg())}°')),
  DataCell(Text(s(row.dV2, 6))),
  DataCell(Text(
      '${s(row.V3.re)} ${row.V3.im >= 0 ? '+' : '-'} j${s(row.V3.im.abs())}')),
  DataCell(Text('${s(row.V3.abs())}∠${s(row.V3.angDeg())}°')),
  DataCell(Text(s(row.dV3, 6))),
],
),
)
.toList(),
),
),

const SizedBox(height: 12),

// Final Voltages in LaTeX format 
latexLeft(
[
r'\textbf{Final } \vec V_2 \approx ' +
f(r.V2final.re, 4) +
(r.V2final.im >= 0 ? r' + j' : r' - j') +
f(r.V2final.im.abs(), 4) +
r'\quad (' +
f(r.V2final.abs(), 4) +
r'\angle ' +
f(r.V2final.angDeg(), 2) +
r'^\circ).',
r'\textbf{Final } \vec V_3 \approx ' +
f(r.V3final.re, 4) +
(r.V3final.im >= 0 ? r' + j' : r' - j') +
f(r.V3final.im.abs(), 4) +
r'\quad (' +
f(r.V3final.abs(), 4) +
r'\angle ' +
f(r.V3final.angDeg(), 2) +
r'^\circ).',
],
size: 16.2,
),
],
);
}

// fixed iterations workinng
Widget _fixedIterationsWork(
GS3Result r,
String Function(C) show,
String Function(C) rect,
) {
String s(double v, [int k = 6]) => sig(v, k);

// Table formatting
String rectPlain(C z, [int k = 4]) =>
'${s(z.re, k)} ${z.im >= 0 ? '+' : '-'} j${s(z.im.abs(), k)}';

String polarPlain(C z, [int k = 4]) =>
'${s(z.abs(), k)}∠${s(z.angDeg(), k)}°';

// LaTeX polar 
String polar(C z, [int k = 4]) =>
'${s(z.abs(), k)}\\angle ${s(z.angDeg(), k)}^{\\circ}';

final nReq = r.fixedItersRequested.clamp(1, 500);
final w = r.worked;
final m = math.min(nReq, w.length);

final isPV2 = r.bus2Type == BusKind.pv;
final isPV3 = r.bus3Type == BusKind.pv;

return Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
const SizedBox(height: 6),
Text(
'Fixed-iteration mode: ran $m iteration(s).',
style: TextStyle(fontWeight: FontWeight.w600, color: Colors.orange[800]),
),
const SizedBox(height: 10),

// Table
SingleChildScrollView(
scrollDirection: Axis.horizontal,
child: DataTable(
columns: const [
DataColumn(label: Text('k')),
DataColumn(label: Text('V2 (rect)')),
DataColumn(label: Text('V2 (polar)')),
DataColumn(label: Text('V3 (rect)')),
DataColumn(label: Text('V3 (polar)')),
],
rows: r.rows.take(m).map((row) {
return DataRow(cells: [
DataCell(Text('${row.k}')),
DataCell(Text(rectPlain(row.V2, 4))),
DataCell(Text(polarPlain(row.V2, 4))),
DataCell(Text(rectPlain(row.V3, 4))),
DataCell(Text(polarPlain(row.V3, 4))),
]);
}).toList(),
),
),

const SizedBox(height: 14),

// Per iteration workings 
for (var i = 0; i < m; i++) ...[
Builder(builder: (_) {
final it = w[i];
final kPrev = it.k - 1;

// PV enforcement 
final pv2Enforced =
isPV2 && (it.V2nextRaw.abs() - it.V2next.abs()).abs() > 1e-9;
final pv3Enforced =
isPV3 && (it.V3nextRaw.abs() - it.V3next.abs()).abs() > 1e-9;

final V1 = r.V1;

final V2k = it.V2k;
final V3k = it.V3k;

final S2 = it.S2;
final S3 = it.S3;

// Recompute terms
final termS2 = S2.conj() / V2k.conj();
final term21 = r.Y21 * V1;
final term23 = r.Y23 * V3k;
final rhs2 = termS2 - term21 - term23;

final V2raw = it.V2nextRaw;
final V2used = it.V2next;

final termS3 = S3.conj() / V3k.conj();
final term31 = r.Y31 * V1;
final term32 = r.Y32 * V2used; 
final rhs3 = termS3 - term31 - term32;

final V3raw = it.V3nextRaw;
final V3used = it.V3next;

final lines = <String>[];

lines.add(
r'\textcolor{red}{\textbf{Iteration ' +
'${it.k}' +
r':}\ (k=' +
'$kPrev' +
r'\to ' +
'${it.k}' +
r')}',
);
lines.add(r'');
lines.add(r'\textbf{Given:}');
lines.add(r'\vec V_1=' + show(V1) + r'.');
lines.add(r'\vec V_2^{(' + '$kPrev' + r')}=' + show(V2k) + r'.');
lines.add(r'\vec V_3^{(' + '$kPrev' + r')}=' + show(V3k) + r'.');
lines.add(
r'(\vec V_2^{*})^{(' +
'$kPrev' +
r')}=(\vec V_2^{(' +
'$kPrev' +
r')})^{*}=' +
polar(V2k.conj()) +
r'.',
);
lines.add(
r'(\vec V_3^{*})^{(' +
'$kPrev' +
r')}=(\vec V_3^{(' +
'$kPrev' +
r')})^{*}=' +
show(V3k.conj()) +
r'.',
);
lines.add(
r'\vec Y_{21}=' +
show(r.Y21) +
r',\ \vec Y_{22}=' +
show(r.Y22) +
r',\ \vec Y_{23}=' +
show(r.Y23) +
r'.',
);
lines.add(
r'\vec Y_{31}=' +
show(r.Y31) +
r',\ \vec Y_{32}=' +
show(r.Y32) +
r',\ \vec Y_{33}=' +
show(r.Y33) +
r'.',
);

// Bus 2: Getting Q2 from S2
final q2 = S2.im;
lines.add(
r'Q_2^{(' + '${it.k}' + r')}='
+ (q2 >= 0 ? '' : '-') + sig(q2.abs(), 6)
+ (isPV2
? r'\ \textcolor{red}{(\text{Remember: PV bus updates }Q_2\text{ after each iteration})}.'
: r'.'),
);

lines.add(r'\vec S_2^{*}=' + show(S2.conj()) + r'.');

// Bus 3: Getting Q3 from S3
final q3 = S3.im;
lines.add(
r'Q_3^{(' + '${it.k}' + r')}='
+ (q3 >= 0 ? '' : '-') + sig(q3.abs(), 6)
+ (isPV3
? r'\ \textcolor{red}{(\text{Remember: PV bus updates }Q_3\text{ after each iteration})}.'
: r'.'),
);

lines.add(r'\vec S_3^{*}=' + show(S3.conj()) + r'.');
lines.add(r'');

// Update V2
lines.add(r'\textbf{Update }\vec V_2');
lines.add(r'');
lines.add(
r'\textbf{Start from: }\ \vec V_2^{(' +
'${it.k}' +
r')}=\dfrac{1}{\vec Y_{22}}\left[\dfrac{\vec S_2^{*}}{(\vec V_2^{*})^{(' +
'$kPrev' +
r')}}-\vec Y_{21}\vec V_1-\vec Y_{23}\vec V_3^{(' +
'$kPrev' +
r')}\right].',
);
lines.add(r'');

lines.add(
r'1)\ \textbf{Compute the power term: }\ \dfrac{\vec S_2^{*}}{(\vec V_2^{*})^{(' +
'$kPrev' +
r')}}'
r'=\dfrac{' +
polar(S2.conj()) +
r'}{' +
polar(V2k.conj()) +
r'}'
r'=' +
polar(termS2) +
r'.',
);

lines.add(r'2)\ \textbf{Compute neighbour terms: }');
lines.add(
r'\vec Y_{21}\vec V_1=(' +
polar(r.Y21) +
r')(' +
polar(V1) +
r')=' +
polar(term21) +
r'.',
);
lines.add(
r'\vec Y_{23}\vec V_3^{(' +
'$kPrev' +
r')}=(' +
polar(r.Y23) +
r')(' +
polar(V3k) +
r')=' +
polar(term23) +
r'.',
);

lines.add(
r'3)\ \textbf{Form the bracket (rhs): }\ \text{rhs}_2'
r'=(' +
polar(termS2) +
r')-(' +
polar(term21) +
r')-(' +
polar(term23) +
r')'
r'=' +
polar(rhs2) +
r'.',
);

lines.add(
r'4)\ \textbf{Divide by }\vec Y_{22}\textbf{: }\ \vec V_{2,\text{raw}}^{(' +
'${it.k}' +
r')}=\dfrac{\text{rhs}_2}{\vec Y_{22}}'
r'=\dfrac{' +
polar(rhs2) +
r'}{' +
polar(r.Y22) +
r'}'
r'=' +
show(V2raw) +
r'.',
);

lines.add(r'');
if (pv2Enforced) {
lines.add(r'\textbf{5) PV enforcement (keep angle, fix magnitude):}');
lines.add(r'\Rightarrow\ \vec V_2^{(' + '${it.k}' + r')}=' + polar(V2used) + r'.');
} else {
lines.add(r'\textbf{5) No magnitude enforcement.}');
lines.add(
r'\Rightarrow\ \vec V_2^{(' +
'${it.k}' +
r')}=\vec V_{2,\text{raw}}^{(' +
'${it.k}' +
r')}=' +
show(V2raw) +
r'.',
);
}

lines.add(r'');
lines.add(r'');

// Update V3
lines.add(r'\textbf{Update }\vec V_3');
lines.add(r'');
lines.add(
r'\textbf{Start from: }\ \vec V_3^{(' +
'${it.k}' +
r')}=\dfrac{1}{\vec Y_{33}}\left[\dfrac{\vec S_3^{*}}{(\vec V_3^{*})^{(' +
'$kPrev' +
r')}}-\vec Y_{31}\vec V_1-\vec Y_{32}\vec V_2^{(' +
'${it.k}' +
r')}\right].',
);
lines.add(r'');

lines.add(
r'1)\ \textbf{Compute the power term: }\ \dfrac{\vec S_3^{*}}{(\vec V_3^{*})^{(' +
'$kPrev' +
r')}}'
r'=\dfrac{' +
polar(S3.conj()) +
r'}{' +
polar(V3k.conj()) +
r'}'
r'=' +
polar(termS3) +
r'.',
);

lines.add(r'2)\ \textbf{Compute neighbour terms: }');
lines.add(
r'\vec Y_{31}\vec V_1=(' +
polar(r.Y31) +
r')(' +
polar(V1) +
r')=' +
polar(term31) +
r'.',
);
lines.add(
r'\vec Y_{32}\vec V_2^{(' +
'${it.k}' +
r')}=(' +
polar(r.Y32) +
r')(' +
polar(V2used) +
r')=' +
polar(term32) +
r'.',
);

lines.add(
r'3)\ \textbf{Form the bracket (rhs): }\ \text{rhs}_3'
r'=(' +
polar(termS3) +
r')-(' +
polar(term31) +
r')-(' +
polar(term32) +
r')'
r'=' +
polar(rhs3) +
r'.',
);

lines.add(
r'4)\ \textbf{Divide by }\vec Y_{33}\textbf{: }\ \vec V_{3,\text{raw}}^{(' +
'${it.k}' +
r')}=\dfrac{\text{rhs}_3}{\vec Y_{33}}'
r'=\dfrac{' +
polar(rhs3) +
r'}{' +
polar(r.Y33) +
r'}'
r'=' +
show(V3raw) +
r'.',
);

lines.add(r'');
if (pv3Enforced) {
lines.add(r'\textbf{5) PV enforcement (keep angle, fix magnitude):}');
lines.add(r'\Rightarrow\ \vec V_3^{(' + '${it.k}' + r')}=' + polar(V3used) + r'.');
} else {
lines.add(r'\textbf{5) No magnitude enforcement.}');
lines.add(
r'\Rightarrow\ \vec V_3^{(' +
'${it.k}' +
r')}=\vec V_{3,\text{raw}}^{(' +
'${it.k}' +
r')}=' +
show(V3raw) +
r'.',
);
}

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
}),
const SizedBox(height: 12),
],
],
);
}


// Dispose 
@override
void dispose() {
for (final c in [
_sBaseCtrl,
_vBaseCtrl,
_r12Ctrl,
_x12Ctrl,
_r13Ctrl,
_x13Ctrl,
_r23Ctrl,
_x23Ctrl,
_v1MagCtrl,
_d1Ctrl,
_pg1Ctrl,
_qg1Ctrl,
_pd1Ctrl,
_qd1Ctrl,
_q1MinCtrl,
_q1MaxCtrl,
_v2MagCtrl,
_d2Ctrl,
_pg2Ctrl,
_qg2Ctrl,
_pd2Ctrl,
_qd2Ctrl,
_q2MinCtrl,
_q2MaxCtrl,
_v3MagCtrl,
_d3Ctrl,
_pg3Ctrl,
_qg3Ctrl,
_pd3Ctrl,
_qd3Ctrl,
_q3MinCtrl,
_q3MaxCtrl,
_tolCtrl,
_maxIterCtrl,
_fixedIterCtrl, 
_y11ReCtrl,
_y11ImCtrl,
_y12ReCtrl,
_y12ImCtrl,
_y13ReCtrl,
_y13ImCtrl,
_y22ReCtrl,
_y22ImCtrl,
_y23ReCtrl,
_y23ImCtrl,
_y33ReCtrl,
_y33ImCtrl,
_b12Ctrl,
_b13Ctrl,
_b23Ctrl,
]) {
c.dispose();
}
super.dispose();
}
}
