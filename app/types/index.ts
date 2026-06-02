export interface UserProfile {
  id: number;
  email: string;
  name: string;
  image_url: string | null;
  country: string | null;
  is_admin: boolean;
  created_at: string;
  updated_at: string;
}

export interface Country {
  code: string;
  name: string;
  flag_emoji: string | null;
}

export interface Tournament {
  id: number;
  name: string;
  image_url: string;
  start_date: string;
  end_date: string;
  pools?: Pool[];
  games?: Game[];
}

export interface Team {
  id: number;
  name: string;
  image_url?: string;
}

export interface Group {
  id: number;
  name: string;
  tournament_id: number;
  invite_code: string;
  welcome_message: string;
  description: string | null;
  allow_sneak_peek: boolean;
  correct_team_points: number;
  exact_result_points: number;
  public_at: string | null;
  members: GroupMember[];
}

export interface PublicGroupItem {
  id: number;
  name: string;
  description: string | null;
  tournament_id: number;
  tournament_name: string;
  tournament_image_url: string | null;
  correct_team_points: number;
  exact_result_points: number;
  allow_sneak_peek: boolean;
  bet_mode: number;
  group_play_deadline: string | null;
  public_at: string;
  created_at: string;
  member_count: number;
  is_member: boolean;
}

export interface PublicGroupListResponse {
  items: PublicGroupItem[];
  next_cursor: string;
}

export interface GroupMember {
  user_id: number;
  name: string;
  image_url: string | null;
  score: number;
  normalized_score?: number;
}

export interface Game {
  id: number;
  home_team_id: number;
  away_team_id: number;
  home_team_score: number | null;
  away_team_score: number | null;
  start_date: string;
  status: number;
  pool_id: number;
  pool?: Pool;
}

export interface Bet {
  id: number;
  user_id: number;
  game_id: number;
  group_id: number;
  home_team_score: number;
  away_team_score: number;
  user_points: number;
  processed_at: string | null;
  user?: GroupMember;
}

export interface Pool {
  id: number;
  name: string;
  games?: Game[];
}

export interface ActivityMessage {
  id: number;
  type: string;
  message: unknown;
  timeStamp: Date;
}
