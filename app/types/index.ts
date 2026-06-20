export interface UserProfile {
  id: string;
  email: string;
  name: string;
  image_url: string | null;
  firebase_image_url: string | null;
  country: string | null;
  allow_marketing: boolean;
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
  header_image_url: string | null;
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
  header_image_url: string | null;
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
  user_id: string;
  name: string;
  nickname: string | null;
  image_url: string | null;
  score: number;
  normalized_score?: number;
  access_level: number;
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
  user_id: string;
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

export interface MessageReaction {
  user_id: string;
  emoji_id: string;
  created_at: string;
}

export interface GroupMessage {
  id: number;
  user_id: string;
  group_id: number;
  body: string | null;
  image_url: string | null;
  created_at: string;
  reactions: MessageReaction[];
}

// ===== FIFA result polling (admin) =====
// Wire shapes from betty-api internal/fifa (admin /fifa endpoints). Admin-only
// operator tooling; not part of the player wire contract or the native clients.

export interface FifaSeason {
  label: string;
  season_id: string;
}

export interface FifaLinkResult {
  competition_id: string;
  match_count: number;
}

export interface FifaMappingSuggestion {
  game_id: number;
  match_id: string;
  orientation_flipped: boolean;
  ambiguous: boolean;
  // True when this game already has a confirmed mapping (hidden from the to-do list).
  confirmed: boolean;
  // Display enrichment from the backend. game_* are always set; fifa_* are empty
  // for an ambiguous (unmatched) game.
  game_home_team: string;
  game_away_team: string;
  game_start_date: string;
  fifa_home_team: string;
  fifa_away_team: string;
  fifa_start_time: string;
}

export interface FifaMappings {
  competition_id: string;
  suggestions: FifaMappingSuggestion[];
}

export type FifaProposalKind = 'initial' | 'correction' | 'rollback';
export type FifaProposalStatus = 'pending' | 'applied' | 'dismissed' | 'superseded';
export type FifaProposalSource = 'proposal' | 'auto';

export interface FifaResultProposal {
  id: number;
  game_id: number;
  match_id: string;
  home_team_score: number;
  away_team_score: number;
  kind: FifaProposalKind;
  status: FifaProposalStatus;
  source: FifaProposalSource;
  prev_home_score: number | null;
  prev_away_score: number | null;
  feed_hash: number;
  // Display enrichment from the backend: the betty game's teams + kickoff. The
  // score above is already oriented to betty's home/away.
  game_home_team: string;
  game_away_team: string;
  game_start_date: string;
}

export interface FifaUnmappedResult {
  competition_id: string;
  match_id: string;
  home_team: string;
  away_team: string;
  home_score: number;
  away_score: number;
  start_time: string;
}
