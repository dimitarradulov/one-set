export type AppUserRow = {
  id: string;
  clerk_user_id: string;
  email: string;
  display_name: string | null;
  created_at: string;
  updated_at: string;
};

export type AppUserInsert = {
  id?: string;
  clerk_user_id: string;
  email: string;
  display_name?: string | null;
  created_at?: string;
  updated_at?: string;
};

export type AppUserUpdate = {
  clerk_user_id?: string;
  email?: string;
  display_name?: string | null;
  updated_at?: string;
};

export interface Database {
  public: {
    Tables: {
      app_users: {
        Row: AppUserRow;
        Insert: AppUserInsert;
        Update: AppUserUpdate;
        Relationships: [];
      };
    };
    Views: Record<string, never>;
    Functions: Record<string, never>;
  };
}
