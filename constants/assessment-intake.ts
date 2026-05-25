import type { AssessmentIntakeQuestion, AssessmentIntakeQuestionId } from '@/types/assessment';

export const ASSESSMENT_INTAKE_TOTAL_STEPS = 11;

export const MAIN_GOAL_IDS = [
  'build_muscle',
  'get_stronger',
  'recomp',
  'maintain_with_less_time',
  'return_after_break',
] as const;

export const TRAINING_EXPERIENCE_IDS = [
  'new',
  'less_than_1_year',
  '1_to_3_years',
  '3_to_5_years',
  '5_plus_years',
] as const;

export const HIT_EXPERIENCE_IDS = [
  'none',
  'tried_before',
  'understands_failure',
  'long_time_hit',
] as const;

export const DAYS_AVAILABLE_IDS = ['1', '2', '3', '4', 'not_sure'] as const;

export const SESSION_LENGTH_IDS = ['20', '30', '45', '60'] as const;

export const EQUIPMENT_ACCESS_IDS = [
  'full_gym',
  'basic_gym',
  'home_gym',
  'dumbbells_only',
  'machines_mostly',
  'bodyweight_only',
] as const;

export const RECOVERY_PROFILE_IDS = [
  'fast',
  'average',
  'sore_for_days',
  'often_drained',
  'not_sure',
] as const;

export const LIFESTYLE_STRESS_IDS = [
  'low',
  'moderate',
  'high',
  'physical_job',
  'desk_job',
] as const;

export const LIMITATION_IDS = [
  'shoulders',
  'lower_back',
  'knees',
  'elbows',
  'wrists',
  'neck',
  'no_limitations',
] as const;

export const TRAINING_DIRECTION_IDS = [
  'lean_athletic',
  'powerhouse',
  'classic_balanced',
  'upper_body_emphasis',
  'minimalist_muscle',
  'let_oneset_choose',
] as const;

export const FAILURE_COMFORT_IDS = [
  'reps_in_reserve',
  'push_hard_not_every_set',
  'comfortable_to_failure',
  'advanced_intensity',
] as const;

export const ASSESSMENT_INTAKE_QUESTIONS = [
  {
    id: 'main-goal',
    answerKey: 'mainGoal',
    selectionMode: 'single',
    progressStep: 1,
    route: '/main-goal',
    previousRoute: '/(onboarding)',
    nextRoute: '/training-experience',
    question: 'What is your main goal right now?',
    helperText: 'Pick the result you care about most right now.',
    options: [
      { label: 'Build muscle', value: 'build_muscle' },
      { label: 'Get stronger', value: 'get_stronger' },
      { label: 'Recomp my body', value: 'recomp' },
      { label: 'Maintain muscle with less time', value: 'maintain_with_less_time' },
      { label: 'Return after a break', value: 'return_after_break' },
    ],
  },
  {
    id: 'training-experience',
    answerKey: 'trainingExperience',
    selectionMode: 'single',
    progressStep: 2,
    route: '/training-experience',
    previousRoute: '/main-goal',
    nextRoute: '/hit-experience',
    question: 'How long have you been lifting consistently?',
    helperText: 'Choose the answer that best matches your recent training history.',
    options: [
      { label: 'New to lifting', value: 'new' },
      { label: 'Less than 1 year', value: 'less_than_1_year' },
      { label: '1-3 years', value: '1_to_3_years' },
      { label: '3-5 years', value: '3_to_5_years' },
      { label: '5+ years', value: '5_plus_years' },
    ],
  },
  {
    id: 'hit-experience',
    answerKey: 'hitExperience',
    selectionMode: 'single',
    progressStep: 3,
    route: '/hit-experience',
    previousRoute: '/training-experience',
    nextRoute: '/days-available',
    question: 'Have you trained with HIT before?',
    helperText: 'This helps OneSet set the right starting intensity.',
    options: [
      { label: 'No, this is new to me', value: 'none' },
      { label: "I've tried it a few times", value: 'tried_before' },
      { label: 'Yes, I understand training to failure', value: 'understands_failure' },
      { label: "Yes, I've used HIT for a long time", value: 'long_time_hit' },
    ],
  },
  {
    id: 'days-available',
    answerKey: 'daysAvailablePerWeek',
    selectionMode: 'single',
    progressStep: 4,
    route: '/days-available',
    previousRoute: '/hit-experience',
    nextRoute: '/session-length',
    question: 'How many days per week can you realistically train?',
    helperText: 'Choose what you can repeat consistently, not your ideal week.',
    options: [
      { label: '1 day', value: '1' },
      { label: '2 days', value: '2' },
      { label: '3 days', value: '3' },
      { label: '4 days', value: '4' },
      { label: 'Not sure', value: 'not_sure' },
    ],
  },
  {
    id: 'session-length',
    answerKey: 'preferredSessionLength',
    selectionMode: 'single',
    progressStep: 5,
    route: '/session-length',
    previousRoute: '/days-available',
    nextRoute: '/equipment-access',
    question: 'How long do you want each workout to be?',
    helperText: 'OneSet will keep the recommendation brief and focused.',
    options: [
      { label: '20 minutes', value: '20' },
      { label: '30 minutes', value: '30' },
      { label: '45 minutes', value: '45' },
      { label: '60 minutes', value: '60' },
    ],
  },
  {
    id: 'equipment-access',
    answerKey: 'equipmentAccess',
    selectionMode: 'single',
    progressStep: 6,
    route: '/equipment-access',
    previousRoute: '/session-length',
    nextRoute: '/recovery-profile',
    question: 'What equipment do you have access to?',
    helperText: 'Pick the setup you will use for most workouts.',
    options: [
      { label: 'Full gym', value: 'full_gym' },
      { label: 'Basic gym', value: 'basic_gym' },
      { label: 'Home gym', value: 'home_gym' },
      { label: 'Dumbbells only', value: 'dumbbells_only' },
      { label: 'Machines mostly', value: 'machines_mostly' },
      { label: 'Bodyweight only', value: 'bodyweight_only' },
    ],
  },
  {
    id: 'recovery-profile',
    answerKey: 'recoveryProfile',
    selectionMode: 'single',
    progressStep: 7,
    route: '/recovery-profile',
    previousRoute: '/equipment-access',
    nextRoute: '/lifestyle-stress',
    question: 'How well do you usually recover from hard training?',
    helperText: 'Recovery helps set frequency and effort.',
    options: [
      { label: 'I recover quickly', value: 'fast' },
      { label: 'Average', value: 'average' },
      { label: 'I get sore for days', value: 'sore_for_days' },
      { label: 'I often feel drained', value: 'often_drained' },
      { label: "I'm not sure", value: 'not_sure' },
    ],
  },
  {
    id: 'lifestyle-stress',
    answerKey: 'lifestyleStress',
    selectionMode: 'single',
    progressStep: 8,
    route: '/lifestyle-stress',
    previousRoute: '/recovery-profile',
    nextRoute: '/limitations',
    question: 'How demanding is your current lifestyle?',
    helperText: 'Sleep, stress, and physical work affect recovery.',
    options: [
      { label: 'Low stress, good sleep', value: 'low' },
      { label: 'Moderate stress', value: 'moderate' },
      { label: 'High stress, poor sleep', value: 'high' },
      { label: 'Physically demanding job', value: 'physical_job' },
      { label: 'Desk job, mostly sedentary', value: 'desk_job' },
    ],
  },
  {
    id: 'limitations',
    answerKey: 'limitations',
    selectionMode: 'multiple',
    progressStep: 9,
    route: '/limitations',
    previousRoute: '/lifestyle-stress',
    nextRoute: '/training-direction',
    question: 'Any areas we should be careful with?',
    helperText: 'Select all that apply.',
    options: [
      { label: 'No limitations', value: 'no_limitations' },
      { label: 'Shoulders', value: 'shoulders' },
      { label: 'Lower back', value: 'lower_back' },
      { label: 'Knees', value: 'knees' },
      { label: 'Elbows', value: 'elbows' },
      { label: 'Wrists', value: 'wrists' },
      { label: 'Neck', value: 'neck' },
    ],
  },
  {
    id: 'training-direction',
    answerKey: 'trainingDirection',
    selectionMode: 'single',
    progressStep: 10,
    route: '/training-direction',
    previousRoute: '/limitations',
    nextRoute: '/failure-comfort',
    question: 'Which result sounds most like what you want?',
    helperText: 'OneSet will choose the training structure behind the scenes.',
    options: [
      { label: 'Lean Athletic', value: 'lean_athletic' },
      { label: 'Powerhouse', value: 'powerhouse' },
      { label: 'Classic Balanced', value: 'classic_balanced' },
      { label: 'Upper-Body Emphasis', value: 'upper_body_emphasis' },
      { label: 'Minimalist Muscle', value: 'minimalist_muscle' },
      { label: 'Let OneSet Choose', value: 'let_oneset_choose' },
    ],
  },
  {
    id: 'failure-comfort',
    answerKey: 'failureComfort',
    selectionMode: 'single',
    progressStep: 11,
    route: '/failure-comfort',
    previousRoute: '/training-direction',
    nextRoute: '/result-calculation',
    question: 'How comfortable are you training close to muscular failure?',
    helperText: 'This sets the right starting Effort Level.',
    options: [
      { label: 'I prefer to stop with reps in reserve', value: 'reps_in_reserve' },
      { label: 'I can push hard, but not every set', value: 'push_hard_not_every_set' },
      { label: "I'm comfortable going to failure", value: 'comfortable_to_failure' },
      { label: 'I use advanced intensity techniques', value: 'advanced_intensity' },
    ],
  },
] as const satisfies readonly AssessmentIntakeQuestion[];

export const getAssessmentIntakeQuestion = (questionId: AssessmentIntakeQuestionId) => {
  const question = ASSESSMENT_INTAKE_QUESTIONS.find((item) => item.id === questionId);

  if (!question) {
    throw new Error(`Unknown Assessment Intake question: ${questionId}`);
  }

  return question;
};
