// lib/domain/powerflow_solver_gs2.dart
import 'dart:math' as math;
import 'complex.dart';
import 'powerflow_model_gs2.dart';

double _toPuPower({
required double value,
required bool inPu,
required double sBaseMVA,
}) {
return inPu ? value : (value / sBaseMVA);
}

C _enforceMag(C v, double magSpec) {
final ang = math.atan2(v.im, v.re);
return C.fromPolar(magSpec, ang);
}

// GS2 solver 
GS2Result solveGs2WithWorkings(GS2Inputs ip) {
final isPV = ip.bus2Type == BusType.pv;

final maxIterUI = ip.maxIterUI.clamp(1, 500);
final kTimesUI = ip.kTimesUI.clamp(1, 500);
final maxIter = ip.iterateUntilConverge ? maxIterUI : kTimesUI;

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


// Convert Bus 2 powers to pu 
final Pg2pu = _toPuPower(value: ip.pg2, inPu: ip.bus2PowerInPu, sBaseMVA: ip.sBaseMVA);
final Qg2pu_in = _toPuPower(value: ip.qg2, inPu: ip.bus2PowerInPu, sBaseMVA: ip.sBaseMVA);
final Pd2pu = _toPuPower(value: ip.pd2, inPu: ip.bus2PowerInPu, sBaseMVA: ip.sBaseMVA);
final Qd2pu = _toPuPower(value: ip.qd2, inPu: ip.bus2PowerInPu, sBaseMVA: ip.sBaseMVA);

// Net P2
final P2net = Pg2pu - Pd2pu;

// Net complex power at bus 2 
final Sg2_in = C(Pg2pu, Qg2pu_in);
final Sd2 = C(Pd2pu, Qd2pu);
final S2_userPQ = Sg2_in - Sd2;

// Voltages
final V1 = C.fromPolar(ip.v1Mag, ip.d1Deg);
final V20_user = C.fromPolar(ip.v2Mag, ip.d2Deg);

// PV/PQ start values
C V20_used = V20_user;
bool pvDroppedToPQ_at0 = false;

double Q2_used0 = (isPV ? 0.0 : (Qg2pu_in - Qd2pu));
double Qg2_used0 = (isPV ? 0.0 : Qg2pu_in);

// PV worked example k=0
final term21_0 = Y21 * V1;
final term22_0 = Y22 * V20_user;
final sumY2_0 = term21_0 + term22_0;
final prodPV2_0 = V20_user.conj() * sumY2_0;

double q2Raw_0 = 0.0;
double qg2Raw_0 = 0.0;
bool qg2LowViol_0 = false;
bool qg2HighViol_0 = false;

if (isPV) {
q2Raw_0 = -prodPV2_0.im;
qg2Raw_0 = q2Raw_0 + Qd2pu;

var qg2Clamped_0 = qg2Raw_0;
if (qg2MinPu != null && qg2Clamped_0 < qg2MinPu) {
qg2LowViol_0 = true;
qg2Clamped_0 = qg2MinPu;
}
if (qg2MaxPu != null && qg2Clamped_0 > qg2MaxPu) {
qg2HighViol_0 = true;
qg2Clamped_0 = qg2MaxPu;
}

final violatedAt0 = qg2LowViol_0 || qg2HighViol_0;
pvDroppedToPQ_at0 = violatedAt0;

Qg2_used0 = violatedAt0 ? qg2Clamped_0 : qg2Raw_0;
Q2_used0 = Qg2_used0 - Qd2pu;

if (violatedAt0) {
V20_used = C.fromPolar(1.0, 0.0); // flat start 
} else {
V20_used = V20_user;
}
}

final S2_used0 = C(P2net, Q2_used0);
final S2star_used0 = S2_used0.conj();

// Constant form A,B
final A0 = S2star_used0 / Y22;
final B0 = (C.zero - (Y21 * V1)) / Y22;

// First two iterations 

// Iteration 1
final termS0 = S2star_used0 / V20_used.conj();
final termY0 = Y21 * V1;
final rhs0 = termS0 - termY0;
final V21_raw = rhs0 / Y22;

C V21_used = V21_raw;
if (isPV && !pvDroppedToPQ_at0) {
V21_used = _enforceMag(V21_raw, ip.v2Mag);
}

double Q2_used1 = Q2_used0;
double Qg2_used1 = Qg2_used0;

// k=1 PV calc terms
final term21_1 = Y21 * V1;
final term22_1 = Y22 * V21_used;
final sumY2_1 = term21_1 + term22_1;
final prodPV2_1 = V21_used.conj() * sumY2_1;

double q2Raw_1 = 0.0;
double qg2Raw_1 = 0.0;
bool qg2LowViol_1 = false;
bool qg2HighViol_1 = false;
bool pvDroppedLater = false;

if (isPV && !pvDroppedToPQ_at0) {
q2Raw_1 = -prodPV2_1.im;
qg2Raw_1 = q2Raw_1 + Qd2pu;

var qg2Clamped_1 = qg2Raw_1;
if (qg2MinPu != null && qg2Clamped_1 < qg2MinPu) {
qg2LowViol_1 = true;
qg2Clamped_1 = qg2MinPu;
}
if (qg2MaxPu != null && qg2Clamped_1 > qg2MaxPu) {
qg2HighViol_1 = true;
qg2Clamped_1 = qg2MaxPu;
}

final violated1 = qg2LowViol_1 || qg2HighViol_1;
if (violated1) {
pvDroppedLater = true; // PV→PQ 
Qg2_used1 = qg2Clamped_1;
Q2_used1 = Qg2_used1 - Qd2pu;
} else {
Qg2_used1 = qg2Raw_1;
Q2_used1 = q2Raw_1;
}
}

// Iteration 2 uses S2 based on updated Q2_used1
final S2_used1 = C(P2net, Q2_used1);
final S2star_used1 = S2_used1.conj();

final termS1 = S2star_used1 / V21_used.conj();
final termY1 = Y21 * V1;
final rhs1 = termS1 - termY1;
final V22_raw = rhs1 / Y22;

C V22_used = V22_raw;
if (isPV && !pvDroppedToPQ_at0 && !pvDroppedLater) {
V22_used = _enforceMag(V22_raw, ip.v2Mag);
}

// Full iteration rows (convergence or k-times)
final rows = <GS2IterRow>[];
var V2k = V20_used;
bool converged = false;

bool pvModeActive = isPV && !pvDroppedToPQ_at0;
bool pqFixedFromLimit = isPV && pvDroppedToPQ_at0;
final Q2_fixed_limit = Q2_used0;

for (var k = 1; k <= maxIter; k++) {
double Q2_forThisUpdate;
bool pvThisIter = false;

if (pqFixedFromLimit) {
Q2_forThisUpdate = Q2_fixed_limit;
pvThisIter = false;
} else if (pvModeActive) {
pvThisIter = true;

final sum = (Y21 * V1) + (Y22 * V2k);
final prod = V2k.conj() * sum;

final q2Raw = -prod.im;
final qg2Raw = q2Raw + Qd2pu;

var qg2Use = qg2Raw;
var lowV = false;
var highV = false;

if (qg2MinPu != null && qg2Use < qg2MinPu) {
lowV = true;
qg2Use = qg2MinPu;
}
if (qg2MaxPu != null && qg2Use > qg2MaxPu) {
highV = true;
qg2Use = qg2MaxPu;
}

if (lowV || highV) {
pvModeActive = false;
pqFixedFromLimit = true;
pvThisIter = false;
Q2_forThisUpdate = qg2Use - Qd2pu;
} else {
Q2_forThisUpdate = q2Raw;
}
} else {
pvThisIter = false;
Q2_forThisUpdate = (Qg2pu_in - Qd2pu);
}

final S2k = C(P2net, Q2_forThisUpdate);
final S2kStar = S2k.conj();

final termS = S2kStar / V2k.conj();
final termY = Y21 * V1;
final rhs = termS - termY;

final V2next_raw = rhs / Y22;

C V2next_used = V2next_raw;
if (isPV && pvThisIter && pvModeActive) {
V2next_used = _enforceMag(V2next_raw, ip.v2Mag);
}

final dV = (V2next_used - V2k).abs();

rows.add(GS2IterRow(
k: k,
vPrev: V2k,
q2Used: Q2_forThisUpdate,
S2: S2k,
S2star: S2kStar,
termS: termS,
termY: termY,
rhs: rhs,
vNextRaw: V2next_raw,
vNextUsed: V2next_used,
pvEnforced: (isPV && pvThisIter && pvModeActive && !pvDroppedToPQ_at0 && !pqFixedFromLimit),
dV: dV,
));

V2k = V2next_used;

if (ip.iterateUntilConverge && dV < ip.tol) {
converged = true;
break;
}
}

final V2final = V2k;

// Slack bus power
final I1 = (Y11 * V1) + (Y12 * V2final);
final S1 = V1 * I1.conj();

// Line flows & losses (2-Bus π model)
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

return GS2Result(
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
P2net: P2net,
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
qg2Used_0: Qg2_used0,
q2Used_0: Q2_used0,
pvDroppedToPQ_at0: pvDroppedToPQ_at0,
S2_used0: S2_used0,
S2star_used0: S2star_used0,
A0: A0,
B0: B0,
termS0: termS0,
termY0: termY0,
rhs0: rhs0,
V21_raw: V21_raw,
V21_used: V21_used,
term21_1: term21_1,
term22_1: term22_1,
sumY2_1: sumY2_1,
prodPV2_1: prodPV2_1,
q2Raw_1: q2Raw_1,
qg2Raw_1: qg2Raw_1,
qg2LowViol_1: qg2LowViol_1,
qg2HighViol_1: qg2HighViol_1,
qg2Used_1: Qg2_used1,
q2Used_1: Q2_used1,
pvDroppedLater: pvDroppedLater,
S2_used1: S2_used1,
S2star_used1: S2star_used1,
termS1: termS1,
termY1: termY1,
rhs1: rhs1,
V22_raw: V22_raw,
V22_used: V22_used,
rows: rows,
converged: converged,
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