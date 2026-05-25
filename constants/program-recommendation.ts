import type { LimitationId } from '@/types/assessment';
import type { ProgramId } from '@/types/program';

export const PROGRAM_IDS = {
  athleticPower: 'athletic-power-hit',
  beginnerBridge: 'beginner-strength-to-hit-bridge',
  classicSymmetry: 'classic-symmetry-full-body-hit',
  foundationFullBody: 'foundation-full-body-hit',
  fourDayMassSplit: 'four-day-mass-split-hit',
  homeMinimalEquipment: 'home-minimal-equipment-hit',
  machineCircuit: 'machine-circuit-hit',
  minimalistRecovery: 'minimalist-recovery-hit',
  negativeControl: 'negative-control-hit',
  preExhaustSpecialist: 'pre-exhaust-specialist-hit',
  restPauseDensity: 'rest-pause-density-hit',
  threeWayPrecision: 'three-way-precision-hit',
  weakPointRotation: 'weak-point-rotation-hit',
} as const satisfies Record<string, ProgramId>;

export const ADVANCED_PROGRAM_IDS = new Set<ProgramId>([
  PROGRAM_IDS.minimalistRecovery,
  PROGRAM_IDS.negativeControl,
  PROGRAM_IDS.restPauseDensity,
  PROGRAM_IDS.weakPointRotation,
  PROGRAM_IDS.athleticPower,
]);

export const MAJOR_LIMITATIONS = new Set<LimitationId>(['shoulders', 'lower_back', 'knees']);
