# Use Clerk Third-Party Auth for Supabase

OneSet uses Clerk as the authentication provider and Supabase as the app data store, so Supabase access should use Clerk session tokens through Supabase Third-Party Auth. The older Clerk/Supabase partner integration guide is useful for the row ownership model, but its JWT-secret/JWT-template setup is deprecated; OneSet will secure user-owned rows with RLS policies that compare the Clerk subject claim to app-owned user records instead.
