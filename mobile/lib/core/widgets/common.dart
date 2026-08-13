import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../data/models.dart';
import '../theme/app_theme.dart';

class PageFrame extends StatelessWidget {
  const PageFrame({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(20, 12, 20, 28),
  });

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 760),
      child: Padding(padding: padding, child: child),
    ),
  );
}

class SectionTitle extends StatelessWidget {
  const SectionTitle({
    super.key,
    required this.title,
    this.eyebrow,
    this.trailing,
  });

  final String title;
  final String? eyebrow;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (eyebrow != null)
                Text(
                  eyebrow!.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5,
                  ),
                ),
              const SizedBox(height: 3),
              Text(title, style: Theme.of(context).textTheme.titleLarge),
            ],
          ),
        ),
        trailing ?? const SizedBox.shrink(),
      ],
    );
  }
}

class PlayerAvatar extends StatelessWidget {
  const PlayerAvatar({
    super.key,
    required this.name,
    this.url,
    this.radius = 22,
  });

  final String name;
  final String? url;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final initials = name
        .trim()
        .split(RegExp(r'\s+'))
        .take(2)
        .map((part) => part.isEmpty ? '' : part[0])
        .join()
        .toUpperCase();
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppTheme.surfaceHigh,
      foregroundColor: AppTheme.primary,
      backgroundImage: url == null ? null : CachedNetworkImageProvider(url!),
      child: url == null
          ? Text(initials, style: const TextStyle(fontWeight: FontWeight.w900))
          : null,
    );
  }
}

class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final Object value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: AppTheme.primary, size: 18),
            const Spacer(),
            Text(
              '$value',
              style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w900),
            ),
            Text(
              label,
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class LeagueLogo extends StatelessWidget {
  const LeagueLogo({super.key, required this.league, this.size = 54});

  final LeagueSummary league;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppTheme.surfaceHigh,
        borderRadius: BorderRadius.circular(size * .28),
        border: Border.all(color: AppTheme.outline),
        image: league.logoUrl == null
            ? null
            : DecorationImage(
                image: CachedNetworkImageProvider(league.logoUrl!),
                fit: BoxFit.cover,
              ),
      ),
      alignment: Alignment.center,
      child: league.logoUrl == null
          ? Text(
              league.name.isEmpty ? 'K' : league.name[0].toUpperCase(),
              style: TextStyle(
                color: AppTheme.primary,
                fontSize: size * .38,
                fontWeight: FontWeight.w900,
              ),
            )
          : null,
    );
  }
}

class MatchCard extends StatelessWidget {
  const MatchCard({super.key, required this.match, required this.onTap});

  final MatchSummary match;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final date = DateFormat(
      'EEE d MMM · HH:mm',
      'it_IT',
    ).format(match.startsAt);
    final response = switch (match.currentResponse) {
      'going' => 'Ci sei',
      'waitlist' => 'Lista attesa',
      'declined' => 'Non ci sei',
      _ => null,
    };
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(17),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Chip(
                    label: Text(match.footballFormat.replaceAll('v', ' vs ')),
                  ),
                  const Spacer(),
                  if (response != null)
                    Text(
                      response,
                      style: const TextStyle(
                        color: AppTheme.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(match.title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(
                match.leagueName,
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  const Icon(Icons.schedule, size: 16, color: AppTheme.primary),
                  const SizedBox(width: 7),
                  Expanded(child: Text(date)),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(
                    Icons.location_on_outlined,
                    size: 16,
                    color: AppTheme.primary,
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      match.locationName,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 13),
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  minHeight: 6,
                  value: (match.goingCount / match.maxPlayers).clamp(0, 1),
                  backgroundColor: AppTheme.surfaceHigh,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                '${match.goingCount}/${match.maxPlayers} giocatori',
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    this.action,
  });

  final IconData icon;
  final String title;
  final String body;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 38),
        child: Column(
          children: [
            CircleAvatar(
              radius: 25,
              backgroundColor: AppTheme.primary.withValues(alpha: .12),
              child: Icon(icon, color: AppTheme.primary),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 7),
            Text(
              body,
              style: const TextStyle(color: Colors.white54),
              textAlign: TextAlign.center,
            ),
            if (action != null) ...[const SizedBox(height: 20), action!],
          ],
        ),
      ),
    );
  }
}

String friendlyError(Object error) {
  final text = error.toString();
  if (text.contains('Invalid login credentials')) {
    return 'Email o password non corrette.';
  }
  if (text.contains('User already registered')) {
    return 'Esiste già un account con questa email.';
  }
  if (text.contains('username')) return 'Questo username non è disponibile.';
  if (text.contains('league_full')) {
    return 'La lega ha raggiunto il numero massimo di membri.';
  }
  if (text.contains('invalid_invite')) return 'Il codice invito non è valido.';
  return 'Qualcosa non ha funzionato. Riprova tra poco.';
}
