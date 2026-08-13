-- Phase 7 E2E Test Setup Migration
-- Fixes RLS policies and configures test infrastructure

-- ============================================================================
-- 1. FIX: Allow direct inserts to league_members for authenticated users
-- ============================================================================

ALTER TABLE public.league_members ENABLE ROW LEVEL SECURITY;

-- INSERT policy
DROP POLICY IF EXISTS "Users can insert league membership requests"
  ON public.league_members;

CREATE POLICY "Users can insert league membership requests"
  ON public.league_members
  FOR INSERT
  TO authenticated
  WITH CHECK (user_id = auth.uid());

-- UPDATE policy
DROP POLICY IF EXISTS "Users can update own league membership"
  ON public.league_members;

CREATE POLICY "Users can update own league membership"
  ON public.league_members
  FOR UPDATE
  TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

-- ============================================================================
-- 2. FIX: Allow inserts to player_rating_history for authenticated users
-- ============================================================================

ALTER TABLE public.player_rating_history ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users insert own rating history"
  ON public.player_rating_history;

DROP POLICY IF EXISTS "Users read rating history"
  ON public.player_rating_history;

CREATE POLICY "Users insert own rating history"
  ON public.player_rating_history
  FOR INSERT
  TO authenticated
  WITH CHECK (user_id = auth.uid());

CREATE POLICY "Users read rating history"
  ON public.player_rating_history
  FOR SELECT
  TO authenticated
  USING (
    user_id = auth.uid()
    OR EXISTS (
      SELECT 1
      FROM public.matches
      WHERE id = match_id
        AND visibility = 'public'
    )
  );

-- ============================================================================
-- Summary
-- ============================================================================
-- This migration:
-- ✓ Allows authenticated users to insert league membership requests
-- ✓ Allows authenticated users to update their own memberships
-- ✓ Enables RLS and creates policies for player_rating_history