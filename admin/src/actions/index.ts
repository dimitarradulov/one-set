import { defineAction } from 'astro:actions';
import { env } from 'cloudflare:workers';
import { handleDashboardAction, type DashboardEnvironment } from '../dashboard';

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
};
