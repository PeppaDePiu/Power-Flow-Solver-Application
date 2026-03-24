// lib/domain/powerflow_solver_nr2.dart
import 'dart:math' as math;
import 'complex.dart';
import 'powerflow_model_nr2.dart';

double _toPuPower({
required double value,
required bool inPu,
required double sBaseMVA,
}) {
return inPu ? value : (value / sBaseMVA);
}

class _PQcalc {
final double P;
final double Q;
const _PQcalc({required this.P, required this.Q});
}

class _Jac {
final double dPdD;
final double dPdV;
final double dQdD;
final double dQdV;
const _Jac({required this.dPdD, required this.dPdV, required this.dQdD, required this.dQdV});
}

_PQcalc _calcPQ({
required C Y21,
required C Y22,
required double V1mag,
required double d1, // rad
required double V2mag,
required double d2, // rad
}) {
final G21 = Y21.re, B21 = Y21.im;
final G22 = Y22.re, B22 = Y22.im;

final theta = d2 - d1;
final c = math.cos(theta);
final s = math.sin(theta);

final P = (V2mag * V2mag * G22) + (V2mag * V1mag * (G21 * c + B21 * s));
final Q = (-V2mag * V2mag * B22) + (V2mag * V1mag * (G21 * s - B21 * c));
return _PQcalc(P: P, Q: Q);
}

_Jac _jacobianPQ({
required C Y21,
required C Y22,
required double V1mag,
required double d1, // rad
required double V2mag,
required double d2, // rad
}) {
final G21 = Y21.re, B21 = Y21.im;
final G22 = Y22.re, B22 = Y22.im;

final theta = d2 - d1;
final c = math.cos(theta);
final s = math.sin(theta);

final dPdD = V2mag * V1mag * (-G21 * s + B21 * c);
final dPdV = 2.0 * V2mag * G22 + V1mag * (G21 * c + B21 * s);

final dQdD = V2mag * V1mag * (G21 * c + B21 * s);
final dQdV = -2.0 * V2mag * B22 + V1mag * (G21 * s - B21 * c);

return _Jac(dPdD: dPdD, dPdV: dPdV, dQdD: dQdD, dQdV: dQdV);
}

/// Newton–Raphson 2-bus solver 
NR2Result solveNr2WithWorkings(NR2Inputs ip) {
final isPVUser = ip.bus2Type == BusType.pv;

// Clamp iteration controls 
final maxIterUI = ip.maxIterUI.clamp(1, 500);
final kTimesUI = ip.kTimesUI.clamp(1, 500);
final maxIter = ip.iterateUntilConverge ? maxIterUI : kTimesUI;

// Convert Bus 2 powers to pu 
final Pg2pu = _toPuPower(value: ip.pg2, inPu: ip.bus2PowerInPu, sBaseMVA: ip.sBaseMVA);
final Qg2pu_in = _toPuPower(value: ip.qg2, inPu: ip.bus2PowerInPu, sBaseMVA: ip.sBaseMVA);
final Pd2pu = _toPuPower(value: ip.pd2, inPu: ip.bus2PowerInPu, sBaseMVA: ip.sBaseMVA);
final Qd2pu = _toPuPower(value: ip.qd2, inPu: ip.bus2PowerInPu, sBaseMVA: ip.sBaseMVA);

// PV limits are on Qg2 (generator-side)
final qg2MinPu = ip.qg2Min == null
? null
: _toPuPower(value: ip.qg2Min!, inPu: ip.bus2PowerInPu, sBaseMVA: ip.sBaseMVA);
final qg2MaxPu = ip.qg2Max == null
? null
: _toPuPower(value: ip.qg2Max!, inPu: ip.bus2PowerInPu, sBaseMVA: ip.sBaseMVA);

// Base conversion 
final zBase = (ip.vBaseKV * ip.vBaseKV) / ip.sBaseMVA;
final yBase = 1.0 / zBase;

final z12Pu = ip.lineDataInPu ? C(ip.r12, ip.x12) : (C(ip.r12, ip.x12) / C(zBase, 0.0));
final ypPu = ip.lineDataInPu ? C(0.0, ip.ypImag) : C(0.0, ip.ypImag / yBase);

// Series admittance
final y12Series = C.one / z12Pu;

// π-model shunt at each end 
final yShunt = ypPu;

// Ybus
final Y11 = y12Series + yShunt;
final Y22 = y12Series + yShunt;
final Y12 = C.zero - y12Series;
final Y21 = Y12;

// Voltages (C.fromPolar expects DEGREES)
final V1 = C.fromPolar(ip.v1Mag, ip.d1Deg);
final V20_user = C.fromPolar(ip.v2Mag, ip.d2Deg);

// Net complex power at bus 2
final Sg2_in = C(Pg2pu, Qg2pu_in);
final Sd2 = C(Pd2pu, Qd2pu);
final S2_userPQ = Sg2_in - Sd2;

// Specs
final P2spec = Pg2pu - Pd2pu;
final Q2spec_user = Qg2pu_in - Qd2pu;

// NR internal state (radians)
final d1Rad = ip.d1Deg * math.pi / 180.0;
double d2Rad = ip.d2Deg * math.pi / 180.0;
double v2Mag = ip.v2Mag;

// PV bus checker
bool pvActive = isPVUser;
bool droppedToPQ = false;
double? Q2fixedFromLimit;


// PV k=0 reactive-power check 
final term21_0 = Y21 * V1;
final term22_0 = Y22 * V20_user;
final sumY2_0 = term21_0 + term22_0;
final prodPV2_0 = V20_user.conj() * sumY2_0;

double q2Raw_0 = 0.0;
double qg2Raw_0 = 0.0;
bool qg2LowViol_0 = false;
bool qg2HighViol_0 = false;
double qg2Used_0 = 0.0;
double q2Used_0 = 0.0;
bool pvDroppedToPQ_at0 = false;

C V20_used = V20_user;

if (isPVUser) {
q2Raw_0 = -prodPV2_0.im;
qg2Raw_0 = q2Raw_0 + Qd2pu;

var qg2Clamp = qg2Raw_0;
if (qg2MinPu != null && qg2Clamp < qg2MinPu) {
qg2LowViol_0 = true;
qg2Clamp = qg2MinPu;
}
if (qg2MaxPu != null && qg2Clamp > qg2MaxPu) {
qg2HighViol_0 = true;
qg2Clamp = qg2MaxPu;
}

final violatedAt0 = qg2LowViol_0 || qg2HighViol_0;
pvDroppedToPQ_at0 = violatedAt0;

qg2Used_0 = violatedAt0 ? qg2Clamp : qg2Raw_0;
q2Used_0 = qg2Used_0 - Qd2pu;

if (violatedAt0) {
// PV → PQ and reset to flat start 
pvActive = false;
droppedToPQ = true;
Q2fixedFromLimit = q2Used_0;

v2Mag = 1.0;
d2Rad = 0.0;
V20_used = C.fromPolar(1.0, 0.0);
}
} else {
// PQ not used
qg2Used_0 = Qg2pu_in;
q2Used_0 = Q2spec_user;
}

// NR iterations

final rows = <NR2IterRow>[];
bool converged = false;

for (int k = 1; k <= maxIter; k++) {
final bool inPVMode = (pvActive && isPVUser && !droppedToPQ);

// Power at current state
final calc = _calcPQ(
Y21: Y21,
Y22: Y22,
V1mag: ip.v1Mag,
d1: d1Rad,
V2mag: v2Mag,
d2: d2Rad,
);

// Q specified used (only for PQ or PV dropped)
final Q2specUsed = inPVMode
  ? calc.Q
  : (droppedToPQ ? (Q2fixedFromLimit ?? Q2spec_user) : Q2spec_user);

// Mismatches
final misP = P2spec - calc.P;
final misQ = inPVMode ? 0.0 : (Q2specUsed - calc.Q);

// Jacobian
final jac = _jacobianPQ(
Y21: Y21,
Y22: Y22,
V1mag: ip.v1Mag,
d1: d1Rad,
V2mag: v2Mag,
d2: d2Rad,
);

double dDelta = 0.0;
double dV = 0.0;

if (inPVMode) {
final H = jac.dPdD;
if (H.abs() < 1e-14) {
  throw 'Newton–Raphson Jacobian singular (∂P/∂δ ≈ 0). Try different initial guess.';
}
dDelta = misP / H;
dV = 0.0;

d2Rad += dDelta;
v2Mag = ip.v2Mag; // PV fixes magnitude
} else {
final a = jac.dPdD;
final b = jac.dPdV;
final c = jac.dQdD;
final d = jac.dQdV;

final det = a * d - b * c;
if (det.abs() < 1e-14) {
  throw 'Newton–Raphson Jacobian singular (det ≈ 0). Try different initial guess.';
}

dDelta = (misP * d - b * misQ) / det;
dV = (a * misQ - misP * c) / det;

d2Rad += dDelta;
v2Mag += dV;
}

// Recompute after update 
final calcAfter = _calcPQ(
Y21: Y21,
Y22: Y22,
V1mag: ip.v1Mag,
d1: d1Rad,
V2mag: v2Mag,
d2: d2Rad,
);

// PV Q-limit check after update (only if PV active)
bool pvEnforced = false;
bool droppedThisIter = false;

if (inPVMode) {
pvEnforced = true;

final qg2Calc = calcAfter.Q + Qd2pu;
var qg2Use = qg2Calc;

var low = false;
var high = false;

if (qg2MinPu != null && qg2Use < qg2MinPu) {
  low = true;
  qg2Use = qg2MinPu;
}
if (qg2MaxPu != null && qg2Use > qg2MaxPu) {
  high = true;
  qg2Use = qg2MaxPu;
}

if (low || high) {
  pvActive = false;
  droppedToPQ = true;
  droppedThisIter = true;
  Q2fixedFromLimit = qg2Use - Qd2pu;
}
}

// convergence metric 
final dx = math.max(dDelta.abs(), dV.abs());

rows.add(NR2IterRow(
k: k,
d2Rad: d2Rad,
v2Mag: v2Mag,
p2Calc: calcAfter.P,
q2Calc: calcAfter.Q,
misP: misP,
misQ: inPVMode ? 0.0 : misQ,
dDelta: dDelta,
dV: dV,
pvEnforced: pvEnforced,
droppedToPQ: droppedToPQ,
droppedThisIter: droppedThisIter,
));

if (ip.iterateUntilConverge && dx < ip.tol) {
converged = true;
break;
}
}

// Final V2 (C.fromPolar expects degrees)
final V2final = C.fromPolar(v2Mag, d2Rad * 180.0 / math.pi);

// Slack bus power
final I1 = (Y11 * V1) + (Y12 * V2final);
final S1 = V1 * I1.conj();

// Line flows & losses (π model)
final I12 = (y12Series * (V1 - V2final)) + (yShunt * V1);
final S12 = V1 * I12.conj();

final I21 = (y12Series * (V2final - V1)) + (yShunt * V2final);
final S21 = V2final * I21.conj();

final Sloss = S12 + S21;

// Bus 1 given values (pu)
final Pg1pu = _toPuPower(value: ip.pg1, inPu: ip.bus1PowerInPu, sBaseMVA: ip.sBaseMVA);
final Qg1pu = _toPuPower(value: ip.qg1, inPu: ip.bus1PowerInPu, sBaseMVA: ip.sBaseMVA);
final Pd1pu = _toPuPower(value: ip.pd1, inPu: ip.bus1PowerInPu, sBaseMVA: ip.sBaseMVA);
final Qd1pu = _toPuPower(value: ip.qd1, inPu: ip.bus1PowerInPu, sBaseMVA: ip.sBaseMVA);

final Sg1_given = C(Pg1pu, Qg1pu);
final Sd1_given = C(Pd1pu, Qd1pu);

final Sg1_required_from_Sd1 = S1 + Sd1_given;
final Sd1_required_from_Sg1 = Sg1_given - S1;

return NR2Result(
bus2Type: ip.bus2Type,
bus1Given: ip.bus1Given,
iterateUntilConverge: ip.iterateUntilConverge,
kTimes: kTimesUI,
sBaseMVA: ip.sBaseMVA,
vBaseKV: ip.vBaseKV,
r12: ip.r12,
x12: ip.x12,
ypImag: ip.ypImag,
dataInPu: ip.lineDataInPu,
tol: ip.tol,
maxIter: maxIterUI,
zBase: zBase,
yBase: yBase,
z12Pu: z12Pu,
ypPu: ypPu,
y12Series: y12Series,
yShunt: yShunt,
Y11: Y11,
Y22: Y22,
Y12: Y12,
Y21: Y21,
V1: V1,
V20_user: V20_user,
V20_used: V20_used,
V2spec: ip.v2Mag,
Sg2_in: Sg2_in,
Sd2: Sd2,
S2_userPQ: S2_userPQ,
P2spec: P2spec,
Q2spec_user: Q2spec_user,
qg2min: qg2MinPu,
qg2max: qg2MaxPu,
term21_0: term21_0,
term22_0: term22_0,
sumY2_0: sumY2_0,
prodPV2_0: prodPV2_0,
q2Raw_0: q2Raw_0,
qg2Raw_0: qg2Raw_0,
qg2LowViol_0: qg2LowViol_0,
qg2HighViol_0: qg2HighViol_0,
qg2Used_0: qg2Used_0,
q2Used_0: q2Used_0,
pvDroppedToPQ_at0: pvDroppedToPQ_at0,
rows: rows,
converged: converged,
droppedToPQ: droppedToPQ,
Q2fixedFromLimit: Q2fixedFromLimit,
V2final: V2final,
I1: I1,
S1: S1,
I12: I12,
S12: S12,
I21: I21,
S21: S21,
Sloss: Sloss,
Sg1_given: Sg1_given,
Sd1_given: Sd1_given,
Sg1_required_from_Sd1: Sg1_required_from_Sd1,
Sd1_required_from_Sg1: Sd1_required_from_Sg1,
);
}