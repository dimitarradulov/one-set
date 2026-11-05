import { defineAction } from 'astro:actions';
import { env } from 'cloudflare:workers';
import { handleDashboardAction, type DashboardEnvironment } from '../dashboard';
import { prepareHistoricalRestoration, publishHistoricalRestoration, type HistoryEnvironment } from '../history';

export const server = {
  editProgram: defineAction({
    accept: 'form',
    handler: (input, context) => handleDashboardAction('edit', context.request, input, env as DashboardEnvironment),
  }),
  reviewProgram: defineAction({
    accept: 'form',
    handler: (input, context) => handleDashboardAction('review', context.request, input, env as DashboardEnvironment),
  }),
  publishProgram: defineAction({
    accept: 'form',
    handler: (input, context) => handleDashboardAction('publish', context.request, input, env as DashboardEnvironment),
  }),
  editExercise: defineAction({
    accept: 'form',
    handler: (input, context) => handleDashboardAction('edit-exercise', context.request, input, env as DashboardEnvironment),
  }),
  reviewExercise: defineAction({
    accept: 'form',
    handler: (input, context) => handleDashboardAction('review-exercise', context.request, input, env as DashboardEnvironment),
  }),
  publishExercise: defineAction({
    accept: 'form',
    handler: (input, context) => handleDashboardAction('publish-exercise', context.request, input, env as DashboardEnvironment),
  }),
  restorePublication: defineAction({
    accept: 'form',
    handler: (input, context) => prepareHistoricalRestoration(context.request, input, env as HistoryEnvironment),
  }),
  publishRestoration: defineAction({
    accept: 'form',
    handler: (input, context) => publishHistoricalRestoration(context.request, input, env as HistoryEnvironment),
  }),
  syncCatalog: defineAction({
    accept: 'form',
    handler: (input, context) => handleDashboardAction('sync', context.request, input, env as DashboardEnvironment),
  }),
};
