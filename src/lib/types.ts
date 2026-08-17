export type Role = "admin" | "city_head";
export type Status = "pending" | "in_progress" | "submitted" | "approved" | "returned";
export type Category =
  | "attendance"
  | "finance"
  | "inventory"
  | "announcement"
  | "poc_data"
  | "other";

export interface SessionUser {
  token: string;
  user_id: string;
  username: string;
  display_name: string;
  role: Role;
  city_id: number | null;
  city_name: string | null;
}

export interface City {
  id: number;
  name: string;
  region: string | null;
  active: boolean;
}

export interface Task {
  id: string;
  title: string;
  description: string | null;
  category: Category;
  due_date: string | null;
  attachment_url: string | null;
  archived: boolean;
  created_at: string;
}

export interface Assignment {
  id: string;
  task_id: string;
  city_id: number;
  status: Status;
  note: string | null;
  proof_url: string | null;
  review_note: string | null;
  submitted_at: string | null;
  reviewed_at: string | null;
  updated_at: string;
}

export interface Activity {
  id: number;
  assignment_id: string | null;
  actor_name: string;
  action: string;
  detail: string | null;
  created_at: string;
}

export interface UserRow {
  id: string;
  username: string;
  display_name: string;
  role: Role;
  city_id: number | null;
  city_name: string | null;
  active: boolean;
}
