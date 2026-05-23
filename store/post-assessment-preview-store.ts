import { create } from 'zustand';

import { PROGRAM_LIBRARY } from '@/constants/program-library';
import type { PostAssessmentPreviewStoreState } from '@/types/post-assessment-preview-store';
import { buildPostAssessmentPreviewState } from '@/utils/post-assessment-preview';

export const createPostAssessmentPreviewStore = () =>
  create<PostAssessmentPreviewStoreState>()((set) => ({
    preparedState: null,
    prepareRecommendation: (draft) => {
      const preparedState = buildPostAssessmentPreviewState(draft, PROGRAM_LIBRARY);

      set({ preparedState });

      return preparedState;
    },
    clearPreparedState: () => set({ preparedState: null }),
  }));

export const usePostAssessmentPreviewStore = createPostAssessmentPreviewStore();
