import type { AssessmentDraftAnswers, LimitationId } from '@/types/assessment';
import type {
  CompleteAssessmentDraft,
  HitReadiness,
  InternalTrainingLevel,
  ProgramId,
  ProgramLibrary,
  ProgramLibraryEntry,
  ProgramRecommendation,
  RecoveryCapacity,
} from '@/types/program';

const PROGRAM_IDS = {
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

const ADVANCED_PROGRAM_IDS = new Set<ProgramId>([
  PROGRAM_IDS.minimalistRecovery,
  PROGRAM_IDS.negativeControl,
  PROGRAM_IDS.restPauseDensity,
  PROGRAM_IDS.weakPointRotation,
  PROGRAM_IDS.athleticPower,
]);

const MAJOR_LIMITATIONS = new Set<LimitationId>(['shoulders', 'lower_back', 'knees']);

const assertCompleteAssessmentDraft: (
  draft: AssessmentDraftAnswers
) => asserts draft is CompleteAssessmentDraft = (draft) => {
  for (const [key, value] of Object.entries(draft)) {
    if (Array.isArray(value)) {
      if (value.length === 0) {
        throw new Error(`Program Recommendation requires ${key}`);
      }
    } else if (value === null) {
      throw new Error(`Program Recommendation requires ${key}`);
    }
  }
};

const getTrainingLevel = (draft: CompleteAssessmentDraft): InternalTrainingLevel => {
  if (draft.trainingExperience === 'new' || draft.trainingExperience === 'less_than_1_year') {
    return 'beginner';
  }

  if (draft.trainingExperience === '1_to_3_years') {
    return draft.hitExperience === 'long_time_hit' ? 'intermediate' : 'late_beginner';
  }

  if (draft.trainingExperience === '3_to_5_years') {
    return 'intermediate';
  }

  if (draft.hitExperience === 'none' || draft.hitExperience === 'tried_before') {
    return 'intermediate';
  }

  return 'advanced';
};

const getHitReadiness = (draft: CompleteAssessmentDraft): HitReadiness => {
  if (draft.hitExperience === 'none') {
    return 'new_to_hit';
  }

  if (draft.hitExperience === 'tried_before') {
    return 'learning_hit';
  }

  if (draft.hitExperience === 'understands_failure') {
    return 'ready_for_hit';
  }

  return 'experienced_hit';
};

const getRecoveryCapacity = (draft: CompleteAssessmentDraft): RecoveryCapacity => {
  if (
    draft.recoveryProfile === 'often_drained' ||
    draft.recoveryProfile === 'sore_for_days' ||
    draft.lifestyleStress === 'high' ||
    draft.lifestyleStress === 'physical_job'
  ) {
    return 'limited';
  }

  if (draft.recoveryProfile === 'fast' && draft.lifestyleStress === 'low') {
    return 'good';
  }

  return 'average';
};

const hasMajorLimitations = (limitations: LimitationId[]) =>
  limitations.some((limitation) => MAJOR_LIMITATIONS.has(limitation));

const getStartingEffort = (
  trainingLevel: InternalTrainingLevel,
  hitReadiness: HitReadiness
): ProgramRecommendation['startingEffort'] => {
  if (trainingLevel === 'beginner' || hitReadiness === 'new_to_hit') {
    return '8-9';
  }

  if (trainingLevel === 'late_beginner' || hitReadiness === 'learning_hit') {
    return '9';
  }

  if (trainingLevel === 'intermediate') {
    return '9-10';
  }

  return '10 selectively';
};

const getRecoveryDemand = (programId: ProgramId): ProgramRecommendation['recoveryDemand'] => {
  if (
    programId === PROGRAM_IDS.athleticPower ||
    programId === PROGRAM_IDS.fourDayMassSplit ||
    programId === PROGRAM_IDS.restPauseDensity
  ) {
    return 'very_high';
  }

  if (
    programId === PROGRAM_IDS.threeWayPrecision ||
    programId === PROGRAM_IDS.preExhaustSpecialist ||
    programId === PROGRAM_IDS.negativeControl ||
    programId === PROGRAM_IDS.weakPointRotation
  ) {
    return 'high';
  }

  if (programId === PROGRAM_IDS.minimalistRecovery) {
    return 'low';
  }

  return 'moderate';
};

const isExcluded = (
  program: ProgramLibraryEntry,
  draft: CompleteAssessmentDraft,
  trainingLevel: InternalTrainingLevel,
  hitReadiness: HitReadiness,
  recoveryCapacity: RecoveryCapacity
) => {
  const majorLimitations = hasMajorLimitations(draft.limitations);
  const lowFailureComfort = draft.failureComfort === 'reps_in_reserve';

  if (
    ADVANCED_PROGRAM_IDS.has(program.id) &&
    (trainingLevel === 'beginner' ||
      hitReadiness === 'new_to_hit' ||
      lowFailureComfort ||
      recoveryCapacity === 'limited' ||
      majorLimitations)
  ) {
    return true;
  }

  if (
    program.id === PROGRAM_IDS.athleticPower &&
    (draft.equipmentAccess !== 'full_gym' ||
      majorLimitations ||
      draft.trainingDirection !== 'powerhouse' ||
      draft.failureComfort !== 'advanced_intensity')
  ) {
    return true;
  }

  if (program.id === PROGRAM_IDS.weakPointRotation) {
    return true;
  }

  if (program.id === PROGRAM_IDS.homeMinimalEquipment && draft.equipmentAccess === 'full_gym') {
    return true;
  }

  return false;
};

const getSelectionRankScore = (
  program: ProgramLibraryEntry,
  selectionGroupIds: ProgramLibrary['selectionGroupIds'],
  trainingLevel: InternalTrainingLevel
) => {
  const group = selectionGroupIds[trainingLevel];
  const rank = group.indexOf(program.id);

  if (rank === -1) {
    return 0;
  }

  return 60 - rank * 8;
};

const scoreProgram = (
  program: ProgramLibraryEntry,
  library: ProgramLibrary,
  draft: CompleteAssessmentDraft,
  trainingLevel: InternalTrainingLevel,
  hitReadiness: HitReadiness,
  recoveryCapacity: RecoveryCapacity
) => {
  let score = getSelectionRankScore(program, library.selectionGroupIds, trainingLevel);

  if (
    draft.equipmentAccess === 'home_gym' ||
    draft.equipmentAccess === 'dumbbells_only' ||
    draft.equipmentAccess === 'bodyweight_only'
  ) {
    score += program.id === PROGRAM_IDS.homeMinimalEquipment ? 70 : -30;
  }

  if (draft.equipmentAccess === 'machines_mostly') {
    score += program.id === PROGRAM_IDS.machineCircuit ? 45 : 0;
  }

  if (draft.trainingExperience === 'new') {
    score += program.id === PROGRAM_IDS.beginnerBridge ? 45 : 0;
  }

  if (draft.mainGoal === 'return_after_break') {
    score += program.id === PROGRAM_IDS.foundationFullBody ? 35 : 0;
  }

  if (draft.trainingDirection === 'classic_balanced') {
    score += program.id === PROGRAM_IDS.classicSymmetry ? 35 : 0;
  }

  if (draft.trainingDirection === 'minimalist_muscle' || recoveryCapacity === 'limited') {
    score += program.id === PROGRAM_IDS.minimalistRecovery ? 35 : 0;
    score += program.id === PROGRAM_IDS.foundationFullBody ? 15 : 0;
  }

  if (
    draft.trainingDirection === 'powerhouse' &&
    trainingLevel === 'advanced' &&
    hitReadiness === 'experienced_hit'
  ) {
    score += program.id === PROGRAM_IDS.athleticPower ? 80 : 0;
  }

  if (Number(draft.daysAvailablePerWeek) === program.recommendedDaysPerWeekMin) {
    score += 10;
  }

  return score;
};

const buildWhyItFits = (
  program: ProgramLibraryEntry,
  draft: CompleteAssessmentDraft,
  trainingLevel: InternalTrainingLevel,
  hitReadiness: HitReadiness,
  recoveryCapacity: RecoveryCapacity
) => {
  const reasons = [
    `Matches your ${trainingLevel.replace('_', ' ')} training profile.`,
    hitReadiness === 'new_to_hit'
      ? 'Keeps HIT exposure controlled while you learn hard, clean sets.'
      : 'Fits your current comfort with high-effort HIT work.',
  ];

  if (program.recommendedDaysPerWeekMin && program.recommendedDaysPerWeekMax) {
    reasons.push(
      `Fits a ${program.recommendedDaysPerWeekMin}-${program.recommendedDaysPerWeekMax} day training week.`
    );
  }

  if (draft.equipmentAccess === 'machines_mostly' && program.id === PROGRAM_IDS.machineCircuit) {
    reasons.push('Uses machine-focused training for safer hard effort.');
  }

  if (program.id === PROGRAM_IDS.homeMinimalEquipment) {
    reasons.push('Matches your limited-equipment training setup.');
  }

  if (recoveryCapacity === 'limited') {
    reasons.push('Keeps recovery demand conservative.');
  }

  return reasons.slice(0, 4);
};

export const recommendProgram = (
  draft: AssessmentDraftAnswers,
  library: ProgramLibrary
): ProgramRecommendation => {
  assertCompleteAssessmentDraft(draft);

  const trainingLevel = getTrainingLevel(draft);
  const hitReadiness = getHitReadiness(draft);
  const recoveryCapacity = getRecoveryCapacity(draft);
  const candidates = library.programs.filter(
    (program) => !isExcluded(program, draft, trainingLevel, hitReadiness, recoveryCapacity)
  );

  if (candidates.length === 0) {
    throw new Error('Program Recommendation has no safe candidate programs');
  }

  const [recommendedProgram] = [...candidates].sort(
    (left, right) =>
      scoreProgram(right, library, draft, trainingLevel, hitReadiness, recoveryCapacity) -
        scoreProgram(left, library, draft, trainingLevel, hitReadiness, recoveryCapacity) ||
      left.number - right.number
  );

  return {
    program: recommendedProgram,
    internalAssessment: {
      trainingLevel,
      hitReadiness,
      recoveryCapacity,
    },
    startingEffort: getStartingEffort(trainingLevel, hitReadiness),
    recoveryDemand: getRecoveryDemand(recommendedProgram.id),
    whyItFits: buildWhyItFits(
      recommendedProgram,
      draft,
      trainingLevel,
      hitReadiness,
      recoveryCapacity
    ),
    afterCycle:
      'After 12 completed workouts, OneSet reviews your logbook, recovery, and stalls before changing the plan.',
  };
};
