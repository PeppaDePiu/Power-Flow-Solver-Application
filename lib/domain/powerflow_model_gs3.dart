// lib/domain/powerflow_model_gs3.dart
import 'dart:math' as math;
import 'complex.dart';

enum DisplayMode { rect, polar, both }
enum BusKind { slack, pq, pv }
enum SlackGiven { none, sg1Given, sd1Given }

// Quick Fill Preset model 
class GS3Preset {
final String name;

// toggles
final bool lineDataInPu;
final bool useDirectYbus;

final bool bus1PowersInPu;
final bool bus2PowersInPu;
final bool bus3PowersInPu;

final bool iterate;
final String fixedIterK;
final String tol;
final String maxIter;

// dropdowns
final BusKind bus1Type;
final BusKind bus2Type;
final BusKind bus3Type;
final SlackGiven slackGiven;

// base
final String sBase;
final String vBase;

// line data 
final String r12, x12, r13, x13, r23, x23;

// direct Ybus 
final String y11Re, y11Im, y12Re, y12Im, y13Re, y13Im, y22Re, y22Im, y23Re, y23Im, y33Re, y33Im;

// voltages
final String v1Mag, d1;
final String v2Mag, d2;
final String v3Mag, d3;

// bus powers
final String pg1, qg1, pd1, qd1;
final String pg2, qg2, pd2, qd2;
final String pg3, qg3, pd3, qd3;

// Reactive power limit text controllers
final String q1Min, q1Max;
final String q2Min, q2Max;
final String q3Min, q3Max;

const GS3Preset({
required this.name,
required this.lineDataInPu,
required this.useDirectYbus,
required this.bus1PowersInPu,
required this.bus2PowersInPu,
required this.bus3PowersInPu,
required this.iterate,
required this.fixedIterK,
required this.tol,
required this.maxIter,
required this.bus1Type,
required this.bus2Type,
required this.bus3Type,
required this.slackGiven,
required this.sBase,
required this.vBase,
required this.r12,
required this.x12,
required this.r13,
required this.x13,
required this.r23,
required this.x23,
required this.y11Re,
required this.y11Im,
required this.y12Re,
required this.y12Im,
required this.y13Re,
required this.y13Im,
required this.y22Re,
required this.y22Im,
required this.y23Re,
required this.y23Im,
required this.y33Re,
required this.y33Im,
required this.v1Mag,
required this.d1,
required this.v2Mag,
required this.d2,
required this.v3Mag,
required this.d3,
required this.pg1,
required this.qg1,
required this.pd1,
required this.qd1,
required this.pg2,
required this.qg2,
required this.pd2,
required this.qd2,
required this.pg3,
required this.qg3,
required this.pd3,
required this.qd3,
required this.q1Min,
required this.q1Max,
required this.q2Min,
required this.q2Max,
required this.q3Min,
required this.q3Max,
});
}

// Presets list 
final List<GS3Preset> gs3Presets = [
const GS3Preset(
name: 'Custom (Set all to Zero by Default)',
lineDataInPu: true,
useDirectYbus: true,
bus1PowersInPu: true,
bus2PowersInPu: true,
bus3PowersInPu: true,
iterate: true,
fixedIterK: '0',
tol: '0',
maxIter: '0',
bus1Type: BusKind.slack,
bus2Type: BusKind.pq,
bus3Type: BusKind.pq,
slackGiven: SlackGiven.none,
sBase: '0',
vBase: '0',
r12: '0',
x12: '0',
r13: '0',
x13: '0',
r23: '0',
x23: '0',
y11Re: '0',
y11Im: '0',
y12Re: '0',
y12Im: '0',
y13Re: '0',
y13Im: '0',
y22Re: '0',
y22Im: '0',
y23Re: '0',
y23Im: '0',
y33Re: '0',
y33Im: '0',
v1Mag: '0',
d1: '0',
v2Mag: '0',
d2: '0',
v3Mag: '0',
d3: '0',
pg1: '0',
qg1: '0',
pd1: '0',
qd1: '0',
pg2: '0',
qg2: '0',
pd2: '0',
qd2: '0',
pg3: '0',
qg3: '0',
pd3: '0',
qd3: '0',
q1Min: '',
q1Max: '',
q2Min: '',
q2Max: '',
q3Min: '',
q3Max: '',
),
const GS3Preset(
name: 'Lecture Notes Page 45, 3 Bus GS with Actual values (not per unit)',
lineDataInPu: true,
useDirectYbus: false,
bus1PowersInPu: true,
bus2PowersInPu: false,
bus3PowersInPu: false,
iterate: true,
fixedIterK: '2',
tol: '1e-4',
maxIter: '50',
bus1Type: BusKind.slack,
bus2Type: BusKind.pq,
bus3Type: BusKind.pq,
slackGiven: SlackGiven.none,
sBase: '100',
vBase: '230',
r12: '0.02',
x12: '0.04',
r13: '0.01',
x13: '0.03',
r23: '0.0125',
x23: '0.025',
y11Re: '0',
y11Im: '0',
y12Re: '0',
y12Im: '0',
y13Re: '0',
y13Im: '0',
y22Re: '0',
y22Im: '0',
y23Re: '0',
y23Im: '0',
y33Re: '0',
y33Im: '0',
v1Mag: '1.05',
d1: '0',
v2Mag: '1.0',
d2: '0',
v3Mag: '1.0',
d3: '0',
pg1: '0',
qg1: '0',
pd1: '0',
qd1: '0',
pg2: '0',
qg2: '0',
pd2: '256.6',
qd2: '110.2',
pg3: '0',
qg3: '0',
pd3: '138.6',
qd3: '45.2',
q1Min: '',
q1Max: '',
q2Min: '',
q2Max: '',
q3Min: '',
q3Max: '',
),
const GS3Preset(
name: 'Lecture Notes Page 56, 3 Bus GS with Ybus matrix given without Q-Limits Violation',
lineDataInPu: true,
useDirectYbus: true,
bus1PowersInPu: true,
bus2PowersInPu: true,
bus3PowersInPu: true,
iterate: true,
fixedIterK: '2',
tol: '1e-4',
maxIter: '50',
bus1Type: BusKind.slack,
bus2Type: BusKind.pv,
bus3Type: BusKind.pq,
slackGiven: SlackGiven.none,
sBase: '0',
vBase: '0',
r12: '0',
x12: '0',
r13: '0',
x13: '0',
r23: '0',
x23: '0',
y11Re: '6.67',
y11Im: '-19.89',
y12Re: '-1.67',
y12Im: '5.0',
y13Re: '-5.0',
y13Im: '15.0',
y22Re: '4.17',
y22Im: '-12.4',
y23Re: '-2.5',
y23Im: '7.5',
y33Re: '7.5',
y33Im: '-22.39',
v1Mag: '1.06',
d1: '0',
v2Mag: '1.04',
d2: '0',
v3Mag: '1.0',
d3: '0',
pg1: '0',
qg1: '0',
pd1: '0',
qd1: '0',
pg2: '0.2',
qg2: '0',
pd2: '0',
qd2: '0',
pg3: '0',
qg3: '0',
pd3: '0.6',
qd3: '0.25',
q1Min: '',
q1Max: '',
q2Min: '0.0',
q2Max: '0.3',
q3Min: '',
q3Max: '',
),
const GS3Preset(
name: 'Lecture Notes Page 59, 3 Bus GS with Ybus matrix given with Q-Limits Violation',
lineDataInPu: true,
useDirectYbus: true,
bus1PowersInPu: true,
bus2PowersInPu: true,
bus3PowersInPu: true,
iterate: true,
fixedIterK: '2',
tol: '1e-4',
maxIter: '50',
bus1Type: BusKind.slack,
bus2Type: BusKind.pv,
bus3Type: BusKind.pq,
slackGiven: SlackGiven.none,
sBase: '0',
vBase: '0',
r12: '0',
x12: '0',
r13: '0',
x13: '0',
r23: '0',
x23: '0',
y11Re: '6.67',
y11Im: '-19.89',
y12Re: '-1.67',
y12Im: '5.0',
y13Re: '-5.0',
y13Im: '15.0',
y22Re: '4.17',
y22Im: '-12.4',
y23Re: '-2.5',
y23Im: '7.5',
y33Re: '7.5',
y33Im: '-22.39',
v1Mag: '1.06',
d1: '0',
v2Mag: '1.04',
d2: '0',
v3Mag: '1.0',
d3: '0',
pg1: '0',
qg1: '0',
pd1: '0',
qd1: '0',
pg2: '0.2',
qg2: '0',
pd2: '0',
qd2: '0',
pg3: '0',
qg3: '0',
pd3: '0.6',
qd3: '0.25',
q1Min: '',
q1Max: '',
q2Min: '0.2',
q2Max: '0.5',
q3Min: '',
q3Max: '',
),
const GS3Preset(
name: 'Tutorial 2 Qn 1, 3 Bus GS ignore Q-limits violation',
lineDataInPu: true,
useDirectYbus: false,
bus1PowersInPu: true,
bus2PowersInPu: true,
bus3PowersInPu: true,
iterate: true,
fixedIterK: '2',
tol: '1e-4',
maxIter: '50',
bus1Type: BusKind.slack,
bus2Type: BusKind.pv,
bus3Type: BusKind.pq,
slackGiven: SlackGiven.none,
sBase: '100',
vBase: '230',
r12: '0',
x12: '0.2',
r13: '0',
x13: '0.4',
r23: '0',
x23: '0.25',
y11Re: '0',
y11Im: '0',
y12Re: '0',
y12Im: '0',
y13Re: '0',
y13Im: '0',
y22Re: '0',
y22Im: '0',
y23Re: '0',
y23Im: '0',
y33Re: '0',
y33Im: '0',
v1Mag: '1.04',
d1: '0',
v2Mag: '1.005',
d2: '0',
v3Mag: '1.0',
d3: '0',
pg1: '0',
qg1: '0',
pd1: '0',
qd1: '0',
pg2: '1',
qg2: '0',
pd2: '0',
qd2: '0',
pg3: '0',
qg3: '0',
pd3: '1',
qd3: '0.8',
q1Min: '',
q1Max: '',
q2Min: '',
q2Max: '',
q3Min: '',
q3Max: '',
),
const GS3Preset(
name: 'PYP 2021-2022 Qn1, 3 Bus GS, ignore Q-limits violation, Sg1 = S1 = S12',
lineDataInPu: true,
useDirectYbus: false,
bus1PowersInPu: true,
bus2PowersInPu: true,
bus3PowersInPu: true,
iterate: true,
fixedIterK: '2',
tol: '1e-4',
maxIter: '50',
bus1Type: BusKind.slack,
bus2Type: BusKind.pv,
bus3Type: BusKind.pq,
slackGiven: SlackGiven.none,
sBase: '100',
vBase: '230',
r12: '0.02',
x12: '0.04',
r13: '0',
x13: '0',
r23: '0.01',
x23: '0.05',
y11Re: '0',
y11Im: '0',
y12Re: '0',
y12Im: '0',
y13Re: '0',
y13Im: '0',
y22Re: '0',
y22Im: '0',
y23Re: '0',
y23Im: '0',
y33Re: '0',
y33Im: '0',
v1Mag: '1.04',
d1: '0',
v2Mag: '1.02',
d2: '0',
v3Mag: '1.0',
d3: '0',
pg1: '0',
qg1: '0',
pd1: '0',
qd1: '0',
pg2: '0.5',
qg2: '0',
pd2: '0',
qd2: '0',
pg3: '0',
qg3: '0',
pd3: '1',
qd3: '1',
q1Min: '',
q1Max: '',
q2Min: '',
q2Max: '',
q3Min: '',
q3Max: '',
),
const GS3Preset(
name: 'PYP 2024-2025 Qn1, 3 Bus GS, with Q-limits at Bus 3, also need find Sg1',
lineDataInPu: true,
useDirectYbus: false,
bus1PowersInPu: true,
bus2PowersInPu: true,
bus3PowersInPu: true,
iterate: true,
fixedIterK: '2',
tol: '1e-4',
maxIter: '50',
bus1Type: BusKind.slack,
bus2Type: BusKind.pq,
bus3Type: BusKind.pv,
slackGiven: SlackGiven.sd1Given,
sBase: '100',
vBase: '230',
r12: '0.01',
x12: '0.03',
r13: '0',
x13: '0',
r23: '0.04',
x23: '0.08',
y11Re: '0',
y11Im: '0',
y12Re: '0',
y12Im: '0',
y13Re: '0',
y13Im: '0',
y22Re: '0',
y22Im: '0',
y23Re: '0',
y23Im: '0',
y33Re: '0',
y33Im: '0',
v1Mag: '1.0',
d1: '0',
v2Mag: '1.0',
d2: '0',
v3Mag: '1.05',
d3: '0',
pg1: '0',
qg1: '0',
pd1: '0.6',
qd1: '0.25',
pg2: '0',
qg2: '0',
pd2: '2.5',
qd2: '1.5',
pg3: '1',
qg3: '0',
pd3: '0',
qd3: '0',
q1Min: '',
q1Max: '',
q2Min: '',
q2Max: '',
q3Min: '0',
q3Max: '0.3',
),
];

/// Numeric inputs bundle passed to solver 
class GS3Inputs {
// toggles
final bool lineDataInPu;
final bool useDirectYbus;

final bool bus1PowersInPu;
final bool bus2PowersInPu;
final bool bus3PowersInPu;

// iteration mode
final bool iterateUntilConverge;
final int fixedItersRequestedUI;
final double tol;
final int maxIterUI;

// dropdowns
final BusKind bus1Type;
final BusKind bus2Type;
final BusKind bus3Type;
final SlackGiven slackGiven;

// base
final double sBaseMVA;
final double vBaseKV;

// line data
final double r12, x12, r13, x13, r23, x23;

// direct ybus entries 
final double y11Re, y11Im, y12Re, y12Im, y13Re, y13Im, y22Re, y22Im, y23Re, y23Im, y33Re, y33Im;

// voltages
final double v1Mag, d1Deg;
final double v2Mag, d2Deg;
final double v3Mag, d3Deg;

// bus powers 
final double pg1, qg1, pd1, qd1;
final double pg2, qg2, pd2, qd2;
final double pg3, qg3, pd3, qd3;

// Q-limits at each bus if its a PV bus
final double? q1Min, q1Max;
final double? q2Min, q2Max;
final double? q3Min, q3Max;

const GS3Inputs({
required this.lineDataInPu,
required this.useDirectYbus,
required this.bus1PowersInPu,
required this.bus2PowersInPu,
required this.bus3PowersInPu,
required this.iterateUntilConverge,
required this.fixedItersRequestedUI,
required this.tol,
required this.maxIterUI,
required this.bus1Type,
required this.bus2Type,
required this.bus3Type,
required this.slackGiven,
required this.sBaseMVA,
required this.vBaseKV,
required this.r12,
required this.x12,
required this.r13,
required this.x13,
required this.r23,
required this.x23,
required this.y11Re,
required this.y11Im,
required this.y12Re,
required this.y12Im,
required this.y13Re,
required this.y13Im,
required this.y22Re,
required this.y22Im,
required this.y23Re,
required this.y23Im,
required this.y33Re,
required this.y33Im,
required this.v1Mag,
required this.d1Deg,
required this.v2Mag,
required this.d2Deg,
required this.v3Mag,
required this.d3Deg,
required this.pg1,
required this.qg1,
required this.pd1,
required this.qd1,
required this.pg2,
required this.qg2,
required this.pd2,
required this.qd2,
required this.pg3,
required this.qg3,
required this.pd3,
required this.qd3,
required this.q1Min,
required this.q1Max,
required this.q2Min,
required this.q2Max,
required this.q3Min,
required this.q3Max,
});
}

class GS3IterRow {
final int k;
final double Q2; // NET Q2 
final C V2;
final double dV2;
final C V3;
final double dV3;

const GS3IterRow({
required this.k,
required this.Q2,
required this.V2,
required this.dV2,
required this.V3,
required this.dV3,
});
}

// Single iteration (k>=1)
class GS3WorkedIter {
final int k;

final C V2k;
final C V3k;

final C S2;
final C S3;

final C partS2overV2;
final C neigh21;
final C neigh23;
final C rhsV2;
final C V2nextRaw;
final C V2next;

final C partS3overV3;
final C neigh31;
final C neigh32;
final C rhsV3;
final C V3nextRaw;
final C V3next;

const GS3WorkedIter({
required this.k,
required this.V2k,
required this.V3k,
required this.S2,
required this.S3,
required this.partS2overV2,
required this.neigh21,
required this.neigh23,
required this.rhsV2,
required this.V2nextRaw,
required this.V2next,
required this.partS3overV3,
required this.neigh31,
required this.neigh32,
required this.rhsV3,
required this.V3nextRaw,
required this.V3next,
});
}

// Full workings result 
class GS3Result {
// inputs
final double sBaseMVA;
final double vBaseKV;
final bool lineDataInPu;
final double zBase;
final double yBase;

final double r12, x12, r13, x13, r23, x23;

// pu impedances
final C z12pu, z13pu, z23pu;

// admittances
final C y12, y13, y23;

// Ybus
final List<List<C>> Ybus;
final C Y11, Y12, Y13, Y21, Y22, Y23, Y31, Y32, Y33;

// bus types
final BusKind bus1Type, bus2Type, bus3Type;

// Slack given-at selection
final SlackGiven slackGiven;

// power toggles
final bool bus1PowersInPu, bus2PowersInPu, bus3PowersInPu;

// optional Q-limits (generator-side)
final double? Q1min;
final double? Q1max;
final double? Q2min;
final double? Q2max;
final double? Q3min;
final double? Q3max;

// per-bus powers in pu (after conversion)
final double Pg1, Qg1, Pd1, Qd1;
final double Pg2, Qg2, Pd2, Qd2;
final double Pg3, Qg3, Pd3, Qd3;

// loads (entered)
final C Sd1_entered, Sd2, Sd3;

// generator at bus1 (entered)
final C Sg1_entered;

// net power specs (Sg - Sd)
final C S1spec, S2spec, S3spec;

// voltages
final C V1;
final C V2_0_input, V3_0_input;
final C V2_0_forGS, V3_0_forGS;

// PV step (bus 2) at k=0
final C term21, term22, term23, sumY2;
final C prodPV2_0;

// net vs generator-side Q at bus 2
final double Q2_net_raw_0;
final double Qg2_raw_0;
final double Qg2_used_0;
final double Q2_net_used_0;
final bool Qg2_low_viol_0;
final bool Qg2_high_viol_0;
final bool bus2DroppedToPQ_0;
final C S2_0;

// PV step (bus 3) at k=0
final C term31, term32, term33, sumY3;
final C prodPV3_0;

// net vs generator-side Q at bus 3
final double Q3_net_raw_0;
final double Qg3_raw_0;
final double Qg3_used_0;
final double Q3_net_used_0;
final bool Qg3_low_viol_0;
final bool Qg3_high_viol_0;
final bool bus3DroppedToPQ_0;
final C S3_0;

// GS intermediates (k=0 → 1)
final C partS2overV2, rhsV2, V2newRaw, V2new;
final C partS3overV3, rhsV3, V3newRaw, V3new;

// iteration
final double tol;
final int maxIter;
final bool iterate;
final int fixedItersRequested;
final bool converged;
final List<GS3IterRow> rows;
final List<GS3WorkedIter> worked;

final C V2final, V3final;

// slack & generation
final C I1;
final C S1net;

// slack resolved final load/gen depending on dropdown
final C Sd1_final;
final C Sg1_final;

final C S2netFinal;
final C Sg2;

final C S3netFinal;
final C Sg3;

// flows & losses
final C I12, S12, I21, S21, Sloss12;
final C I13, S13, I31, S31, Sloss13;
final C I23, S23, I32, S32, Sloss23;
final C SlossTotal;

const GS3Result({
required this.sBaseMVA,
required this.vBaseKV,
required this.lineDataInPu,
required this.zBase,
required this.yBase,
required this.r12,
required this.x12,
required this.r13,
required this.x13,
required this.r23,
required this.x23,
required this.z12pu,
required this.z13pu,
required this.z23pu,
required this.y12,
required this.y13,
required this.y23,
required this.Ybus,
required this.Y11,
required this.Y12,
required this.Y13,
required this.Y21,
required this.Y22,
required this.Y23,
required this.Y31,
required this.Y32,
required this.Y33,
required this.bus1Type,
required this.bus2Type,
required this.bus3Type,
required this.slackGiven,
required this.bus1PowersInPu,
required this.bus2PowersInPu,
required this.bus3PowersInPu,
required this.Q1min,
required this.Q1max,
required this.Q2min,
required this.Q2max,
required this.Q3min,
required this.Q3max,
required this.Pg1,
required this.Qg1,
required this.Pd1,
required this.Qd1,
required this.Pg2,
required this.Qg2,
required this.Pd2,
required this.Qd2,
required this.Pg3,
required this.Qg3,
required this.Pd3,
required this.Qd3,
required this.Sd1_entered,
required this.Sd2,
required this.Sd3,
required this.Sg1_entered,
required this.S1spec,
required this.S2spec,
required this.S3spec,
required this.V1,
required this.V2_0_input,
required this.V3_0_input,
required this.V2_0_forGS,
required this.V3_0_forGS,
required this.term21,
required this.term22,
required this.term23,
required this.sumY2,
required this.prodPV2_0,
required this.Q2_net_raw_0,
required this.Qg2_raw_0,
required this.Qg2_used_0,
required this.Q2_net_used_0,
required this.Qg2_low_viol_0,
required this.Qg2_high_viol_0,
required this.bus2DroppedToPQ_0,
required this.S2_0,
required this.term31,
required this.term32,
required this.term33,
required this.sumY3,
required this.prodPV3_0,
required this.Q3_net_raw_0,
required this.Qg3_raw_0,
required this.Qg3_used_0,
required this.Q3_net_used_0,
required this.Qg3_low_viol_0,
required this.Qg3_high_viol_0,
required this.bus3DroppedToPQ_0,
required this.S3_0,
required this.partS2overV2,
required this.rhsV2,
required this.V2newRaw,
required this.V2new,
required this.partS3overV3,
required this.rhsV3,
required this.V3newRaw,
required this.V3new,
required this.tol,
required this.maxIter,
required this.iterate,
required this.fixedItersRequested,
required this.converged,
required this.rows,
required this.worked,
required this.V2final,
required this.V3final,
required this.I1,
required this.S1net,
required this.Sd1_final,
required this.Sg1_final,
required this.S2netFinal,
required this.Sg2,
required this.S3netFinal,
required this.Sg3,
required this.I12,
required this.S12,
required this.I21,
required this.S21,
required this.Sloss12,
required this.I13,
required this.S13,
required this.I31,
required this.S31,
required this.Sloss13,
required this.I23,
required this.S23,
required this.I32,
required this.S32,
required this.Sloss23,
required this.SlossTotal,
});
}

// Helper extension for complex-number operations 
extension CMathCompat on C {
double abs() => math.sqrt(re * re + im * im);
double angDeg() => math.atan2(im, re) * 180.0 / math.pi;
}

// Utility extension for complex-number magnitude and angle
extension CNeg on C {
C operator -() => C(-re, -im);
}