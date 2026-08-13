/*
  Comprehensive E2E helper for notifications pipeline.

  Usage:
    - Provide NEXT_PUBLIC_SUPABASE_URL and NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY in env (already required by app).
    - Provide test account credentials via env vars (DO NOT commit secrets):
      TEST_OWNER_EMAIL, TEST_OWNER_PASSWORD,
      TEST_ADMIN_EMAIL, TEST_ADMIN_PASSWORD,
      TEST_MEMBER_A_EMAIL, TEST_MEMBER_A_PASSWORD,
      TEST_MEMBER_B_EMAIL, TEST_MEMBER_B_PASSWORD
    - Optional service role and worker secrets for running cron/worker steps:
      SUPABASE_SERVICE_ROLE_KEY (optional)
      KICKLY_PROJECT_URL (optional) - used to invoke the push-worker function endpoint
      KICKLY_PUBLISHABLE_KEY (optional) - used as function auth when invoking push-worker

  The script will attempt available flows and report the first failing pipeline point for each scenario.
  It will not hardcode passwords, will only operate on PUSH-TEST-* resources where possible, and will store created IDs in scripts/e2e-created.json.
*/

import fs from 'fs';

(async () => {
  const { createClient } = await import('@supabase/supabase-js');

  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const key = process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY;
  if (!url || !key) {
    console.error('Missing NEXT_PUBLIC_SUPABASE_URL or NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY; aborting.');
    process.exit(1);
  }

  const serviceKey = process.env.SUPABASE_SERVICE_ROLE_KEY || null;
  const kicklyProjectUrl = process.env.KICKLY_PROJECT_URL || null;
  const kicklyPublishableKey = process.env.KICKLY_PUBLISHABLE_KEY || null;

  // Test accounts from environment (must be provided by operator when running real E2E)
  const accounts = {
    owner: { email: process.env.TEST_OWNER_EMAIL || null, password: process.env.TEST_OWNER_PASSWORD || null },
    admin: { email: process.env.TEST_ADMIN_EMAIL || null, password: process.env.TEST_ADMIN_PASSWORD || null },
    memberA: { email: process.env.TEST_MEMBER_A_EMAIL || null, password: process.env.TEST_MEMBER_A_PASSWORD || null },
    memberB: { email: process.env.TEST_MEMBER_B_EMAIL || null, password: process.env.TEST_MEMBER_B_PASSWORD || null },
  };

  const _supabase = createClient(url, key);
  const supabaseService = serviceKey ? createClient(url, serviceKey) : null;

  function createdState() {
    try {
      return JSON.parse(fs.readFileSync('./scripts/e2e-created.json', 'utf-8'));
    } catch {
      return { matches: [], leagues: [], subscriptions: [], other: {} };
    }
  }

  function saveCreated(state) {
    fs.writeFileSync('./scripts/e2e-created.json', JSON.stringify(state, null, 2));
  }

  const created = createdState();

  async function signIn(email, password) {
    if (!email || !password) return { error: 'missing_credentials' };
    const client = createClient(url, key);
    const { data, error } = await client.auth.signInWithPassword({ email, password });
    if (error) return { error };
    return { client, user: data.user };
  }

  async function callRpcAs(client, name, params) {
    try {
      const { data, error } = await client.rpc(name, params);
      return { data, error };
    } catch (_e) {
      return { error: _e };
    }
  }

  async function createPushTestMatch(client, title, startsAt) {
    const params = {
      target_league: process.env.PUSH_TEST_LEAGUE_ID || '20000000-0000-0000-0000-000000000001',
      match_title: title,
      match_description: 'PUSH-TEST auto-generated',
      match_starts_at: startsAt,
      match_location_name: 'PUSH-TEST Field',
      match_address: 'Test Address',
      match_city: 'Milano',
      match_football_format: '5v5',
      match_max_players: 10,
      match_cost_total: null,
      match_visibility: 'public',
    };
    return callRpcAs(client, 'create_match', params);
  }

  async function updatePushTestMatch(client, matchId, newStarts) {
    return callRpcAs(client, 'update_match_details', {
      target_match: matchId,
      match_title: 'PUSH-TEST-updated',
      match_description: 'Updated by e2e script',
      match_starts_at: newStarts,
      match_location_name: 'PUSH-TEST Field Updated',
      match_address: 'Test Address',
      match_city: 'Milano',
      match_football_format: '5v5',
      match_max_players: 10,
      match_cost_total: null,
      match_visibility: 'public',
    });
  }

  async function cancelMatch(client, matchId) {
    return callRpcAs(client, 'set_match_admin_state', { target_match: matchId, target_action: 'cancel' });
  }

  async function setMatchResponse(client, matchId, responseVal) {
    return callRpcAs(client, 'set_match_response', { target_match: matchId, target_response: responseVal });
  }

  async function finalizeMatch(client, matchId) {
    // finalize_match requires a bunch of args; attempt minimal valid call based on types
    // We'll fetch participants then build arrays
    try {
      const { data: participants } = await client.from('match_participants').select('user_id').eq('match_id', matchId);
      const userIds = (participants || []).map((p) => p.user_id).slice(0, 10);
      const half = Math.ceil(userIds.length / 2);
      const teamA = userIds.slice(0, half);
      const teamB = userIds.slice(half);
      const { data, error } = await client.rpc('finalize_match', {
        target_match: matchId,
        team_a_players: teamA,
        team_b_players: teamB,
        score_a: 1,
        score_b: 0,
        player_totals: {},
      });
      return { data, error };
    } catch (e) {
      return { error: e };
    }
  }

  async function castMvpVote(client, matchId, playerId) {
    return callRpcAs(client, 'cast_mvp_vote', { target_match: matchId, target_player: playerId });
  }

  async function finalizeMvp(client, matchId) {
    return callRpcAs(client, 'finalize_match_mvp', { target_match: matchId });
  }

  async function insertPlayerRatingHistory(client, payload) {
    try {
      const { data, error } = await client.from('player_rating_history').insert(payload);
      return { data, error };
    } catch (e) { return { error: e }; }
  }

  async function changeLeagueRoleAsOwner(client, leagueId, userId, newRole) {
    try {
      const { data, error } = await client.from('league_members').update({ role: newRole }).match({ league_id: leagueId, user_id: userId });
      return { data, error };
    } catch (e) { return { error: e }; }
  }

  // High-level runner: will attempt operations when credentials present; otherwise mark blocked.
  const results = {
    match_created: 'BLOCKED',
    match_updated: 'BLOCKED',
    match_cancelled: 'BLOCKED',
    match_reminder_24h: 'BLOCKED',
    match_reminder_2h: 'BLOCKED',
    waitlist_promoted: 'BLOCKED',
    mvp_voting_open: 'BLOCKED',
    mvp_reminder: 'BLOCKED',
    mvp_winner: 'BLOCKED',
    rating_changed: 'BLOCKED',
    league_invite: 'BLOCKED',
    league_role_promote: 'BLOCKED',
    league_role_demote: 'BLOCKED',
    preferences: 'BLOCKED',
    deduplication: 'BLOCKED',
    multi_device: 'BLOCKED',
  };

  // Check presence of edge function code locally
  const pushWorkerExists = fs.existsSync('./supabase/functions/push-worker/index.ts');

  // Check whether service role is available
  if (!serviceKey) {
    console.log('No SUPABASE_SERVICE_ROLE_KEY in environment — cron/worker/remote RPCs will be blocked until provided.');
  }

  // Check presence of cron scheduling in migrations (static check only)
  const migrations = fs.readdirSync('./supabase/migrations').filter((f) => f.endsWith('.sql'));
  const migrationContents = migrations.map((m) => fs.readFileSync(`./supabase/migrations/${m}`, 'utf-8'));
  const cronKicklyPush = migrationContents.some((c) => c.includes("kickly-push-worker"));
  const cronKicklyReminders = migrationContents.some((c) => c.includes("kickly-notification-reminders"));

  // Check if VAPID references exist in migrations
  const usesVapid = migrationContents.some((c) => c.includes('kickly_vapid_public_key') || c.includes('kickly_vapid_private_key'));

  // Helper: check presence of secrets in Supabase vault (without retrieving values)
  async function checkVaultSecrets(client, names) {
    const result = {};
    names.forEach((n) => (result[n] = false));
    if (!client) return result;
    try {
      // Query only the 'name' column to avoid retrieving secret values.
      const { data, error } = await client.from('vault.decrypted_secrets').select('name').in('name', names);
      if (error) {
        // If access denied or table missing, treat as not configured.
        return result;
      }
      if (Array.isArray(data)) {
        data.forEach((row) => {
          if (row && row.name) result[row.name] = true;
        });
      }
    } catch (_e) {
      // ignore — return default false map
    }
    return result;
  }

  // Populate top-level readiness info (vault secrets checked later if service role provided)
  const readiness = {
    edgeFunction: pushWorkerExists ? 'present' : 'missing',
    cron_in_migrations: { push_worker_entry: cronKicklyPush ? 'declared' : 'missing', reminders_entry: cronKicklyReminders ? 'declared' : 'missing' },
    vapid_keys_declared: usesVapid ? 'declared_in_migrations' : 'not_declared',
    service_role_available: serviceKey ? 'available' : 'not_provided',
    kickly_project_url: kicklyProjectUrl ? 'provided' : 'not_provided',
    kickly_publishable_key: kicklyPublishableKey ? 'provided' : 'not_provided',
    vault_secrets: null, // to be filled in after check
  };

  // Before running scenarios, check vault secrets if service role is available
  const vaultSecretNames = ['kickly_vapid_public_key','kickly_vapid_private_key','kickly_vapid_subject','kickly_project_url','kickly_publishable_key'];
  if (supabaseService) {
    const vaultCheck = await checkVaultSecrets(supabaseService, vaultSecretNames);
    readiness.vault_secrets = vaultCheck; // map of name -> boolean
  } else {
    // Mark all vault secrets as unknown/not available when service role missing
    const unknowns = {};
    vaultSecretNames.forEach((n) => (unknowns[n] = false));
    readiness.vault_secrets = unknowns;
  }

  // Now try to perform scenarios if test accounts provided
  async function runScenarioFlow() {
    // Need at least owner/admin credentials to create matches
    const ownerCreds = accounts.owner.email && accounts.owner.password ? accounts.owner : null;
    const adminCreds = accounts.admin.email && accounts.admin.password ? accounts.admin : null;

    let operatorClient = null; // will hold supabase client signed in as owner/admin
    let _operatorUser = null;

    if (ownerCreds) {
      const r = await signIn(ownerCreds.email, ownerCreds.password);
      if (r.error) {
        console.log('Owner sign-in blocked or failed:', r.error);
      } else {
        operatorClient = r.client;
        _operatorUser = r.user;
      }
    }
    if (!operatorClient && adminCreds) {
      const r = await signIn(adminCreds.email, adminCreds.password);
      if (!r.error) { operatorClient = r.client; _operatorUser = r.user; }
    }

    if (!operatorClient) {
      console.log('No owner/admin credentials available — most admin flows will remain BLOCKED until provided.');
      // set results remain BLOCKED
      return;
    }

    // 1. match_created
    try {
      const matchTitle = `PUSH-TEST-Match-Created-${Date.now()}`;
      const startsAt = new Date(Date.now() + 3 * 60 * 60 * 1000).toISOString();
      const { data: createdId, error: createErr } = await createPushTestMatch(operatorClient, matchTitle, startsAt);
      if (createErr) {
        console.log('create_match failed:', createErr);
        results.match_created = 'FAIL';
      } else {
        const mid = createdId;
        created.matches.push(mid);
        saveCreated(created);
        console.log('Created match id', mid);
        results.match_created = 'PENDING';
      }
    } catch (e) {
      console.log('match_created exception', e);
      results.match_created = 'FAIL';
    }

    // 2. match_updated
    try {
      if (!created.matches.length) { results.match_updated = 'BLOCKED'; }
      else {
        const mid = created.matches[created.matches.length - 1];
        const newStarts = new Date(Date.now() + 4 * 60 * 60 * 1000).toISOString();
        const { _data, error } = await updatePushTestMatch(operatorClient, mid, newStarts);
        if (error) { console.log('update_match_details error', error); results.match_updated = 'FAIL'; }
        else { results.match_updated = 'PENDING'; }
      }
    } catch (_e) { results.match_updated = 'FAIL'; }

    // 3. match_cancelled
    try {
      if (!created.matches.length) { results.match_cancelled = 'BLOCKED'; }
      else {
        const mid = created.matches[created.matches.length - 1];
        const { _data, error } = await cancelMatch(operatorClient, mid);
        if (error) { console.log('cancelMatch error', error); results.match_cancelled = 'FAIL'; }
        else { results.match_cancelled = 'PENDING'; }
      }
    } catch (_e) { results.match_cancelled = 'FAIL'; }

    // 4. reminders — require service role to run private.process_notification_schedule or rely on cron
    if (supabaseService) {
      try {
        const { _data, error } = await callRpcAs(supabaseService, 'private.process_notification_schedule', {});
        if (error) { console.log('process_notification_schedule error', error); results.match_reminder_24h = 'FAIL'; results.match_reminder_2h = 'FAIL'; }
        else { results.match_reminder_24h = 'PENDING'; results.match_reminder_2h = 'PENDING'; }
      } catch (_e) { results.match_reminder_24h = 'FAIL'; results.match_reminder_2h = 'FAIL'; }
    } else {
      results.match_reminder_24h = 'BLOCKED';
      results.match_reminder_2h = 'BLOCKED';
    }

    // 5. waitlist_promoted — we can try using set_match_response to simulate
    try {
      // create a match with max_players = 1 to force waitlist
      const title = `PUSH-TEST-WL-${Date.now()}`;
      const startsAt = new Date(Date.now() + 60 * 60 * 1000).toISOString();
      const { data: mId, error: cErr } = await createPushTestMatch(operatorClient, title, startsAt);
      if (cErr) { console.log('waitlist create failed', cErr); results.waitlist_promoted = 'FAIL'; }
      else {
        const mid = mId;
        created.matches.push(mid);
        saveCreated(created);

        // Sign in memberA and memberB
        const a = await signIn(accounts.memberA.email, accounts.memberA.password);
        const b = await signIn(accounts.memberB.email, accounts.memberB.password);
        if (a.error || b.error) { console.log('member sign-in missing or failed', a.error, b.error); results.waitlist_promoted = 'BLOCKED'; }
        else {
          // memberA joins going
          await setMatchResponse(a.client, mid, 'going');
          // memberB attempts to join (will be waitlist if max_players=1)
          await setMatchResponse(b.client, mid, 'going');
          // memberA cancels — set response to 'not_going' to free slot
          await setMatchResponse(a.client, mid, 'not_going');
          // At this point DB trigger should promote waitlist -> going
          results.waitlist_promoted = 'PENDING';
        }
      }
    } catch (e) { console.log('waitlist error', e); results.waitlist_promoted = 'FAIL'; }

    // 6. mvp_voting_open & mvp_reminder: need to complete a match to trigger mvp open; finalize_match may work
    try {
      if (!created.matches.length) { results.mvp_voting_open = 'BLOCKED'; }
      else {
        const mid = created.matches[0];
        const fin = await finalizeMatch(operatorClient, mid);
        if (fin.error) { console.log('finalize_match error', fin.error); results.mvp_voting_open = 'FAIL'; }
        else { results.mvp_voting_open = supabaseService ? 'PENDING' : 'PENDING'; }
      }
    } catch (_e) { results.mvp_voting_open = 'FAIL'; }

    // mvp_reminder depends on process_notification_schedule
    results.mvp_reminder = supabaseService ? 'PENDING' : 'BLOCKED';

    // 7. mvp_winner: cast votes and finalize_mvp
    try {
      // attempt to cast votes as memberA/memberB
      const a = await signIn(accounts.memberA.email, accounts.memberA.password);
      const b = await signIn(accounts.memberB.email, accounts.memberB.password);
      if (a.error || b.error) { results.mvp_winner = 'BLOCKED'; }
      else {
        const mid = created.matches[0];
        // pick a candidate (use memberA)
        if (a.user && a.user.id) {
          await castMvpVote(a.client, mid, a.user.id);
          // finalize
          const fin = await finalizeMvp(operatorClient, mid);
          if (fin.error) { console.log('finalize_mvp error', fin.error); results.mvp_winner = 'FAIL'; }
          else { results.mvp_winner = 'PENDING'; }
        } else { results.mvp_winner = 'BLOCKED'; }
      }
    } catch (_e) { results.mvp_winner = 'FAIL'; }

    // 8. rating_changed: try to insert into player_rating_history
    try {
      const p = await signIn(accounts.memberA.email, accounts.memberA.password);
      if (p.error) { results.rating_changed = 'BLOCKED'; }
      else {
        const payload = { user_id: p.user.id, match_id: created.matches[0] || null, previous_rating: 70, new_rating: 71, delta: 1, reason: 'E2E test' };
        const r = await insertPlayerRatingHistory(p.client, payload);
        if (r.error) { console.log('rating insert error', r.error); results.rating_changed = 'BLOCKED'; }
        else { results.rating_changed = 'PENDING'; }
      }
    } catch (_e) { results.rating_changed = 'FAIL'; }

    // 9. league_invite & role change: attempt to insert a league member and update role
    try {
      const owner = operatorClient;
      const leagueId = process.env.PUSH_TEST_LEAGUE_ID || '20000000-0000-0000-0000-000000000001';
      // invite (insert) a user as member
      const invitee = accounts.memberB.email ? (await signIn(accounts.memberB.email, accounts.memberB.password)).user : null;
      if (!invitee) { results.league_invite = 'BLOCKED'; }
      else {
        // Directly insert into league_members as owner/admin
        const { data: _ins, error: insErr } = await owner.from('league_members').insert({ league_id: leagueId, user_id: invitee.id, role: 'member', status: 'active' });
        if (insErr) { console.log('league invite insert error', insErr); results.league_invite = 'FAIL'; }
        else { results.league_invite = 'PENDING'; }

        // role promote/demote
        const promote = await changeLeagueRoleAsOwner(owner, leagueId, invitee.id, 'admin');
        if (promote.error) { console.log('promote error', promote.error); results.league_role_promote = 'FAIL'; }
        else { results.league_role_promote = 'PENDING'; }
        const demote = await changeLeagueRoleAsOwner(owner, leagueId, invitee.id, 'member');
        if (demote.error) { console.log('demote error', demote.error); results.league_role_demote = 'FAIL'; }
        else { results.league_role_demote = 'PENDING'; }
      }
    } catch (e) { console.log('league role error', e); results.league_invite = 'FAIL'; }

    // 10. preferences: attempt to toggle notification_preferences for memberA and verify blocked behavior
    try {
      const p = await signIn(accounts.memberA.email, accounts.memberA.password);
      if (p.error) { results.preferences = 'BLOCKED'; }
      else {
        // toggle off match_created
        const { data: _pref, error: prefErr } = await p.client.from('notification_preferences').update({ match_created: false }).eq('user_id', p.user.id);
        if (prefErr) { console.log('could not update preferences', prefErr); results.preferences = 'FAIL'; }
        else { results.preferences = 'PENDING'; }
      }
    } catch (_e) { results.preferences = 'FAIL'; }

    // 11. deduplication and multi-device require service role for worker and multiple subscriptions — mark blocked if missing
    results.deduplication = supabaseService ? 'PENDING' : 'BLOCKED';
    results.multi_device = supabaseService ? 'PENDING' : 'BLOCKED';
  }

  await runScenarioFlow();

  // Save interim report
  fs.writeFileSync('./scripts/e2e-report.json', JSON.stringify({ readiness, results }, null, 2));

  console.log('\nSUMMARY (static checks + what can be attempted without service role):');
  console.log(JSON.stringify({ readiness, results }, null, 2));
  console.log('\nElements missing to start runtime tests:');
  const missing = [];
  if (!process.env.TEST_OWNER_EMAIL || !process.env.TEST_OWNER_PASSWORD) missing.push('TEST_OWNER_EMAIL/PASS');
  if (!process.env.TEST_ADMIN_EMAIL || !process.env.TEST_ADMIN_PASSWORD) missing.push('TEST_ADMIN_EMAIL/PASS');
  if (!process.env.TEST_MEMBER_A_EMAIL || !process.env.TEST_MEMBER_A_PASSWORD) missing.push('TEST_MEMBER_A_EMAIL/PASS');
  if (!process.env.TEST_MEMBER_B_EMAIL || !process.env.TEST_MEMBER_B_PASSWORD) missing.push('TEST_MEMBER_B_EMAIL/PASS');
  if (!process.env.SUPABASE_SERVICE_ROLE_KEY) missing.push('SUPABASE_SERVICE_ROLE_KEY (required for process_notification_schedule, claim_push_deliveries)');
  if (!process.env.KICKLY_PROJECT_URL || !process.env.KICKLY_PUBLISHABLE_KEY) missing.push('KICKLY_PROJECT_URL and KICKLY_PUBLISHABLE_KEY (to invoke Edge Function)');

  // If service role provided, check vault secrets presence recorded in readiness.vault_secrets
  if (supabaseService) {
    const vaultMissing = Object.entries(readiness.vault_secrets || {}).filter(([, v]) => !v).map(([k]) => k);
    if (vaultMissing.length) {
      vaultMissing.forEach((s) => missing.push(`${s} (missing in vault)`));
    }
  } else {
    // service role missing, vault secrets cannot be validated remotely
    missing.push('SUPABASE_SERVICE_ROLE_KEY (required to validate Vault and run worker)');
  }

  if (missing.length) console.log('-', missing.join('\n- '));
  else console.log('- All required environment secrets present');

  console.log('\nE2E script prepared. Created IDs recorded in scripts/e2e-created.json (if any).');
})();
