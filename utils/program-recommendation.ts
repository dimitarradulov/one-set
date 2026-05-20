import type { AssessmentDraftAnswers, LimitationId } from '@/constants/assessment-intake';
import type {
  ProgramLibrary,
  ProgramLibraryEntry,
  ProgramSelectionLevel,
} from '@/utils/program-library-parser';

type CompleteAssessmentDraft = {
  [Key in keyof AssessmentDraftAnswers]-?: NonNullable<AssessmentDraftAnswers[Key]>;
};

type InternalTrainingLevel = ProgramSelectionLevel;
type HitReadiness = 'new_to_hit' | 'learning_hit' | 'ready_for_hit' | 'experienced_hit';
type RecoveryCapacity = 'good' | 'average' | 'limited';

export type ProgramRecommendation = {
  program: ProgramLibraryEntry;
  internalAssessment: {
    trainingLevel: InternalTrainingLevel;
    hitReadiness: HitReadiness;
    recoveryCapacity: RecoveryCapacity;
  };
  startingEffort: '8-9' | '9' | '9-10' | '10 selectively';
  recoveryDemand: 'low' | 'moderate' | 'high' | 'very_high';
  whyItFits: string[];
  afterCycle: string;
};

const ADVANCED_PROGRAM_NAMES = new Set([
  'Minimalist Recovery HIT',
  'Negative-Control HIT',
  'Rest-Pause Density HIT',
  'Weak-Point Rotation HIT',
  'Athletic Power HIT',
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

const getRecoveryDemand = (programName: string): ProgramRecommendation['recoveryDemand'] => {
  if (
    programName === 'Athletic Power HIT' ||
    programName === 'Four-Day Mass Split HIT' ||
    programName === 'Rest-Pause Density HIT'
  ) {
    return 'very_high';
  }

  if (
    programName === 'Three-Way Precision HIT' ||
    programName === 'Pre-Exhaust Specialist HIT' ||
    programName === 'Negative-Control HIT' ||
    programName === 'Weak-Point Rotation HIT'
  ) {
    return 'high';
  }

  if (programName === 'Minimalist Recovery HIT') {
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
    ADVANCED_PROGRAM_NAMES.has(program.name) &&
    (trainingLevel === 'beginner' ||
      hitReadiness === 'new_to_hit' ||
      lowFailureComfort ||
      recoveryCapacity === 'limited' ||
      majorLimitations)
  ) {
    return true;
  }

  if (
    program.name === 'Athletic Power HIT' &&
    (draft.equipmentAccess !== 'full_gym' ||
      majorLimitations ||
      draft.trainingDirection !== 'powerhouse' ||
      draft.failureComfort !== 'advanced_intensity')
  ) {
    return true;
  }

  if (program.name === 'Weak-Point Rotation HIT') {
    return true;
  }

  if (program.name === 'Home Minimal Equipment HIT' && draft.equipmentAccess === 'full_gym') {
    return true;
  }

  return false;
};

const getSelectionRankScore = (
  program: ProgramLibraryEntry,
  selectionGroups: ProgramLibrary['selectionGroups'],
  trainingLevel: InternalTrainingLevel
) => {
  const group = selectionGroups[trainingLevel];
  const rank = group.indexOf(program.name);

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
  let score = getSelectionRankScore(program, library.selectionGroups, trainingLevel);

  if (
    draft.equipmentAccess === 'home_gym' ||
    draft.equipmentAccess === 'dumbbells_only' ||
    draft.equipmentAccess === 'bodyweight_only'
  ) {
    score += program.name === 'Home Minimal Equipment HIT' ? 70 : -30;
  }

  if (draft.equipmentAccess === 'machines_mostly') {
    score += program.name === 'Machine Circuit HIT' ? 45 : 0;
  }

  if (draft.trainingExperience === 'new') {
    score += program.name === 'Beginner Strength-to-HIT Bridge' ? 45 : 0;
  }

  if (draft.mainGoal === 'return_after_break') {
    score += program.name === 'Foundation Full-Body HIT' ? 35 : 0;
  }

  if (draft.trainingDirection === 'classic_balanced') {
    score += program.name === 'Classic Symmetry Full-Body HIT' ? 35 : 0;
  }

  if (draft.trainingDirection === 'minimalist_muscle' || recoveryCapacity === 'limited') {
    score += program.name === 'Minimalist Recovery HIT' ? 35 : 0;
    score += program.name === 'Foundation Full-Body HIT' ? 15 : 0;
  }

  if (
    draft.trainingDirection === 'powerhouse' &&
    trainingLevel === 'advanced' &&
    hitReadiness === 'experienced_hit'
  ) {
    score += program.name === 'Athletic Power HIT' ? 80 : 0;
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

  if (draft.equipmentAccess === 'machines_mostly' && program.name === 'Machine Circuit HIT') {
    reasons.push('Uses machine-focused training for safer hard effort.');
  }

  if (program.name === 'Home Minimal Equipment HIT') {
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
    recoveryDemand: getRecoveryDemand(recommendedProgram.name),
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
