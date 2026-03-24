// lib/domain/powerflow_model_gs2.dart
import 'dart:math' as math;
import 'complex.dart';

enum BusType { slack, pq, pv }
enum Bus1Given { none, sg1, sd1 }

// Quick Fill Preset model 
class GS2Preset {
final String name;

// toggles
final bool lineDataInPu;
final bool bus1PowerInPu;
final bool bus2PowerInPu;
final bool iterateUntilConverge;

// dropdowns
final BusType bus1Type;
final BusType bus2Type;
final Bus1Given bus1Given;

// text fields 
final String sBase;
final String vBase;
final String r12;
final String x12;
final String yp;

final String v1Mag;
final String d1;

final String pg1;
final String qg1;
final String pd1;
final String qd1;

final String v2Mag;
final String d2;

final String pg2;
final String qg2;
final String pd2;
final String qd2;

final String qg2Min;
final String qg2Max;

final String tol;
final String maxIter;
final String kTimes;

const GS2Preset({
required this.name,
required this.lineDataInPu,
required this.bus1PowerInPu,
required this.bus2PowerInPu,
required this.iterateUntilConverge,
required this.bus1Type,
required this.bus2Type,
required this.bus1Given,
required this.sBase,
required this.vBase,
required this.r12,
required this.x12,
required this.yp,
required this.v1Mag,
required this.d1,
required this.pg1,
required this.qg1,
required this.pd1,
required this.qd1,
required this.v2Mag,
required this.d2,
required this.pg2,
required this.qg2,
required this.pd2,
required this.qd2,
required this.qg2Min,
required this.qg2Max,
required this.tol,
required this.maxIter,
required this.kTimes,
});
}

// Current presets list 
final List<GS2Preset> gs2Presets = [
const GS2Preset(
name: 'Custom (Set all to Zero by Default)',
lineDataInPu: true,
bus1PowerInPu: true,
bus2PowerInPu: true,
iterateUntilConverge: true,
bus1Type: BusType.slack,
bus2Type: BusType.pq,
bus1Given: Bus1Given.none,
sBase: '0',
vBase: '0',
r12: '0',
x12: '0',
yp: '0',
v1Mag: '0',
d1: '0',
pg1: '0',
qg1: '0',
pd1: '0',
qd1: '0',
v2Mag: '0',
d2: '0',
pg2: '0',
qg2: '0',
pd2: '0',
qd2: '0',
qg2Min: '',
qg2Max: '',
tol: '0',
maxIter: '0',
kTimes: '0',
),
const GS2Preset(
name: 'Lecture Notes Page 36, 2 Bus GS with Shunt Charging Admittance',
lineDataInPu: false,
bus1PowerInPu: true,
bus2PowerInPu: true,
iterateUntilConverge: true,
bus1Type: BusType.slack,
bus2Type: BusType.pq,
bus1Given: Bus1Given.none,
sBase: '100',
vBase: '230',
r12: '20',
x12: '80',
yp: '0.00027',
v1Mag: '1.0',
d1: '0',
pg1: '0',
qg1: '0',
pd1: '0',
qd1: '0',
v2Mag: '1.0',
d2: '0',
pg2: '0',
qg2: '0',
pd2: '1.0',
qd2: '1.0',
qg2Min: '',
qg2Max: '',
tol: '1e-4',
maxIter: '50',
kTimes: '2',
),
const GS2Preset(
name: 'Tutorial 1 Qn 4, 2 Bus GS with Shunt Charging Admittance',
lineDataInPu: true,
bus1PowerInPu: true,
bus2PowerInPu: false,
iterateUntilConverge: false,
bus1Type: BusType.slack,
bus2Type: BusType.pq,
bus1Given: Bus1Given.none,
sBase: '100',
vBase: '230',
r12: '0.04',
x12: '0.08',
yp: '0.1',
v1Mag: '1.0',
d1: '0',
pg1: '0',
qg1: '0',
pd1: '0',
qd1: '0',
v2Mag: '1.0',
d2: '0',
pg2: '0',
qg2: '0',
pd2: '125',
qd2: '55',
qg2Min: '',
qg2Max: '',
tol: '1e-4',
maxIter: '50',
kTimes: '2',
),
const GS2Preset(
name: 'PYP 2022-2023 Qn1, 2 Bus GS with Shunt Charging Admittance and Q-limits Check',
lineDataInPu: true,
bus1PowerInPu: true,
bus2PowerInPu: true,
iterateUntilConverge: false,
bus1Type: BusType.slack,
bus2Type: BusType.pv,
bus1Given: Bus1Given.sd1,
sBase: '100',
vBase: '230',
r12: '0.05',
x12: '0.1',
yp: '0.3',
v1Mag: '1.0',
d1: '0',
pg1: '0',
qg1: '0',
pd1: '1',
qd1: '1',
v2Mag: '1.05',
d2: '0',
pg2: '1.0',
qg2: '0',
pd2: '0.5',
qd2: '0.5',
qg2Min: '0',
qg2Max: '0.4',
tol: '1e-4',
maxIter: '50',
kTimes: '2',
),
];

/// Numeric input bundle passed to the solver 
class GS2Inputs {
// config
final bool lineDataInPu;
final bool bus1PowerInPu;
final bool bus2PowerInPu;
final bool iterateUntilConverge;
final int kTimesUI;

final BusType bus2Type; // pq or pv
final Bus1Given bus1Given;

// base / line
final double sBaseMVA;
final double vBaseKV;
final double r12;
final double x12;
final double ypImag;

// bus 1 voltage
final double v1Mag;
final double d1Deg;

// bus 1 given powers (optional)
final double pg1;
final double qg1;
final double pd1;
final double qd1;

// bus 2 voltage initial/specified
final double v2Mag;
final double d2Deg;

// bus 2 powers 
final double pg2;
final double qg2;
final double pd2;
final double qd2;

// PV Qg limits (generator-side)
final double? qg2Min;
final double? qg2Max;

// iteration
final double tol;
final int maxIterUI;

const GS2Inputs({
required this.lineDataInPu,
required this.bus1PowerInPu,
required this.bus2PowerInPu,
required this.iterateUntilConverge,
required this.kTimesUI,
required this.bus2Type,
required this.bus1Given,
required this.sBaseMVA,
required this.vBaseKV,
required this.r12,
required this.x12,
required this.ypImag,
required this.v1Mag,
required this.d1Deg,
required this.pg1,
required this.qg1,
required this.pd1,
required this.qd1,
required this.v2Mag,
required this.d2Deg,
required this.pg2,
required this.qg2,
required this.pd2,
required this.qd2,
required this.qg2Min,
required this.qg2Max,
required this.tol,
required this.maxIterUI,
});
}

// Iteration row 
class GS2IterRow {
final int k;

final C vPrev;
final C vNextRaw;
final C vNextUsed;

final double q2Used;
final C S2;
final C S2star;

final C termS;
final C termY;
final C rhs;

final bool pvEnforced;
final double dV;

const GS2IterRow({
required this.k,
required this.vPrev,
required this.q2Used,
required this.S2,
required this.S2star,
required this.termS,
required this.termY,
required this.rhs,
required this.vNextRaw,
required this.vNextUsed,
required this.pvEnforced,
required this.dV,
});
}

// Full workings result 
class GS2Result {
// configuration
final BusType bus2Type;
final Bus1Given bus1Given;
final bool iterateUntilConverge;
final int kTimes;

// inputs 
final double sBaseMVA;
final double vBaseKV;
final double r12;
final double x12;
final double ypImag;
final bool dataInPu;
final double tol;
final int maxIter;

// bases
final double zBase;
final double yBase;

// pu values
final C z12Pu;
final C ypPu;

// admittances
final C y12Series;
final C yShunt;

// Ybus
final C Y11, Y22, Y12, Y21;

// voltages
final C V1;
final C V20_user;
final C V20_used;
final double V2spec;

// bus 2 powers 
final C Sg2_in;
final C Sd2;
final C S2_userPQ;
final double P2net;

// PV limits
final double? qg2min;
final double? qg2max;

// PV k=0 terms
final C term21_0, term22_0, sumY2_0, prodPV2_0;
final double q2Raw_0;
final double qg2Raw_0;
final bool qg2LowViol_0;
final bool qg2HighViol_0;
final double qg2Used_0;
final double q2Used_0;
final bool pvDroppedToPQ_at0;
final C S2_used0;
final C S2star_used0;

// constant form
final C A0, B0;

// first iterations
final C termS0, termY0, rhs0, V21_raw, V21_used;

// k=1 PV 
final C term21_1, term22_1, sumY2_1, prodPV2_1;
final double q2Raw_1;
final double qg2Raw_1;
final bool qg2LowViol_1;
final bool qg2HighViol_1;
final double qg2Used_1;
final double q2Used_1;
final bool pvDroppedLater;
final C S2_used1;
final C S2star_used1;

final C termS1, termY1, rhs1, V22_raw, V22_used;

// iteration
final List<GS2IterRow> rows;
final bool converged;
final C V2final;

// slack power
final C I1;
final C S1;

// flows
final C I12, S12, I21, S21, Sloss; 

// bus 1 Given + Derived
final C Sg1_given;
final C Sd1_given;
final C Sg1_required_from_Sd1;
final C Sd1_required_from_Sg1;

const GS2Result({
required this.bus2Type,
required this.bus1Given,
required this.iterateUntilConverge,
required this.kTimes,
required this.sBaseMVA,
required this.vBaseKV,
required this.r12,
required this.x12,
required this.ypImag,
required this.dataInPu,
required this.tol,
required this.maxIter,
required this.zBase,
required this.yBase,
required this.z12Pu,
required this.ypPu,
required this.y12Series,
required this.yShunt,
required this.Y11,
required this.Y22,
required this.Y12,
required this.Y21,
required this.V1,
required this.V20_user,
required this.V20_used,
required this.V2spec,
required this.Sg2_in,
required this.Sd2,
required this.S2_userPQ,
required this.P2net,
required this.qg2min,
required this.qg2max,
required this.term21_0,
required this.term22_0,
required this.sumY2_0,
required this.prodPV2_0,
required this.q2Raw_0,
required this.qg2Raw_0,
required this.qg2LowViol_0,
required this.qg2HighViol_0,
required this.qg2Used_0,
required this.q2Used_0,
required this.pvDroppedToPQ_at0,
required this.S2_used0,
required this.S2star_used0,
required this.A0,
required this.B0,
required this.termS0,
required this.termY0,
required this.rhs0,
required this.V21_raw,
required this.V21_used,
required this.term21_1,
required this.term22_1,
required this.sumY2_1,
required this.prodPV2_1,
required this.q2Raw_1,
required this.qg2Raw_1,
required this.qg2LowViol_1,
required this.qg2HighViol_1,
required this.qg2Used_1,
required this.q2Used_1,
required this.pvDroppedLater,
required this.S2_used1,
required this.S2star_used1,
required this.termS1,
required this.termY1,
required this.rhs1,
required this.V22_raw,
required this.V22_used,
required this.rows,
required this.converged,
required this.V2final,
required this.I1,
required this.S1,
required this.I12,
required this.S12,
required this.I21,
required this.S21,
required this.Sloss,
required this.Sg1_given,
required this.Sd1_given,
required this.Sg1_required_from_Sd1,
required this.Sd1_required_from_Sg1,
});
}

// Helper extension for complex-number operations 
extension CMathCompat on C {
double abs() => math.sqrt(re * re + im * im);
double angDeg() => math.atan2(im, re) * 180.0 / math.pi;
}
