import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart' as fm;
import 'solver_screen_gauss_seidel_2bus.dart';
import 'solver_screen_gauss_seidel_3bus.dart';
import 'solver_screen_newton_raphson_2bus.dart';

class IntroScreen extends StatelessWidget {
const IntroScreen({super.key});

Widget _panelTitle(String text, {double fontSize = 16}) => Padding(
padding: const EdgeInsets.only(bottom: 6),
child: Text(
text,
style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w700),
textAlign: TextAlign.left,
),
);

Widget _bodyText(String text, {double fontSize = 16}) => Text(
text,
style: TextStyle(fontSize: fontSize, height: 1.45),
textAlign: TextAlign.left,
);

@override
Widget build(BuildContext context) {
return LayoutBuilder(
builder: (context, constraints) {
final w = constraints.maxWidth;
final isPhone = w < 600;
final horizontal = isPhone ? 12.0 : w < 1000 ? 20.0 : 28.0;
final contentMaxWidth = w < 1100 ? w : 1100.0;

final bodySize = isPhone ? 15.0 : 16.5;
final titleSize = isPhone ? 15.0 : 16.0;
final eqnSize = isPhone ? 15.5 : 17.0;
final tableFont = isPhone ? 14.5 : 17.0;

return Scaffold(
appBar: AppBar(title: const Text('Power Flow Solver')),
body: SafeArea(
child: Center(
child: ConstrainedBox(
constraints: BoxConstraints(maxWidth: contentMaxWidth),
child: ListView(
padding: EdgeInsets.all(horizontal),
children: [
_panelTitle('Core idea', fontSize: titleSize),
_bodyText(
'Each bus carries four quantities: V (magnitude), δ (phase angle of voltage), P (active power), and Q (reactive power).',
fontSize: bodySize,
),
const SizedBox(height: 8),
_bodyText(
'Net outflow of complex power from bus i is:',
fontSize: bodySize,
),
const SizedBox(height: 6),
Align(
alignment: Alignment.centerLeft,
child: fm.Math.tex(
r'S_i = P_i + jQ_i = S_{Gi} - S_{Di}',
textStyle: TextStyle(fontSize: eqnSize, height: 1.35),
),
),
const SizedBox(height: 8),
_bodyText(
'Arrow into bus ⇒ generator injection (SGi).',
fontSize: bodySize,
),
const SizedBox(height: 4),
_bodyText(
'Arrow out ⇒ power absorbed by load (SDi).',
fontSize: bodySize,
),

const SizedBox(height: 14),

_panelTitle(
'Types of buses & what is specified / solved',
fontSize: titleSize,
),
SingleChildScrollView(
scrollDirection: Axis.horizontal,
child: Align(
alignment: Alignment.centerLeft,
child: fm.Math.tex(
r'\begin{array}{|c|c|c|}\hline'
r'\textbf{Bus} & \textbf{Specified quantities} & \textbf{Quantities to be determined} \\ \hline'
r'\text{Load (PQ)} & P,\ Q & |V|,\ \delta \\ \hline'
r'\text{Generator (PV)} & P,\ |V| & Q,\ \delta \\ \hline'
r'\text{Slack (V}\delta\text{)} & |V|,\ \delta & P,\ Q \\ \hline'
r'\end{array}',
textStyle: TextStyle(fontSize: tableFont, height: 1.35),
),
),
),

const SizedBox(height: 16),

if (isPhone) ...[
SizedBox(
width: double.infinity,
child: FilledButton(
onPressed: () {
Navigator.of(context).push(
MaterialPageRoute(
builder: (_) => const SolverScreenGS2Bus(),
),
);
},
child: const Text('Gauss–Seidel 2 Bus Solver'),
),
),
const SizedBox(height: 12),
SizedBox(
width: double.infinity,
child: FilledButton.tonal(
onPressed: () {
Navigator.of(context).push(
MaterialPageRoute(
builder: (_) => const SolverScreenNR2Bus(),
),
);
},
child: const Text('Newton–Raphson 2 Bus Solver'),
),
),
const SizedBox(height: 12),
SizedBox(
width: double.infinity,
child: ElevatedButton(
onPressed: () {
Navigator.of(context).push(
MaterialPageRoute(
builder: (_) => const SolverScreenGS3Bus(),
),
);
},
child: const Text('Gauss–Seidel 3 Bus Solver'),
),
),
] else ...[
Wrap(
spacing: 12,
runSpacing: 12,
children: [
FilledButton(
onPressed: () {
Navigator.of(context).push(
MaterialPageRoute(
builder: (_) => const SolverScreenGS2Bus(),
),
);
},
child: const Text('Gauss–Seidel 2 Bus Solver'),
),
FilledButton.tonal(
onPressed: () {
Navigator.of(context).push(
MaterialPageRoute(
builder: (_) => const SolverScreenNR2Bus(),
),
);
},
child: const Text('Newton–Raphson 2 Bus Solver'),
),
ElevatedButton(
onPressed: () {
Navigator.of(context).push(
MaterialPageRoute(
builder: (_) => const SolverScreenGS3Bus(),
),
);
},
child: const Text('Gauss–Seidel 3 Bus Solver'),
),
],
),
],
],
),
),
),
),
);
},
);
}
}

