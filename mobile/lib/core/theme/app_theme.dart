import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';

/// Tema Kickly, allineato ai token di `src/app/globals.css` della PWA.
///
/// I valori non sono scelti a occhio: sono la conversione degli stessi oklch
/// usati sul web, così le due app si assomigliano davvero invece di limitarsi
/// ad avere lo stesso verde.
class AppTheme {
  // --- Colori (conversione dei token oklch della PWA) ---

  /// `--primary: oklch(0.88 0.245 128)`. Il verde acido del marchio.
  static const primary = Color(0xFFC7FF3D);

  /// `--primary-foreground: oklch(0.15 0.025 128)`. Testo sopra il verde.
  static const onPrimary = Color(0xFF0E1A05);

  /// `--background: oklch(0.105 0.005 145)`.
  static const background = Color(0xFF0B0D0C);

  /// `--card: oklch(0.165 0.008 145)`.
  static const surface = Color(0xFF181C19);

  /// `--secondary` / `--muted`: superficie rialzata per input e chip.
  static const surfaceHigh = Color(0xFF222722);

  /// `--border: oklch(1 0 0 / 10%)`.
  ///
  /// Sul web il bordo è bianco traslucido, non un grigio pieno: è quello che dà
  /// alle card l'aria "di vetro" che la versione mobile non aveva.
  static const outline = Color(0x1AFFFFFF);

  /// Variante opaca del bordo, per i punti in cui serve un colore pieno
  /// (per esempio i bordi disegnati sopra a un'immagine).
  static const outlineSolid = Color(0xFF2A302B);

  /// `--foreground: oklch(0.985 0 0)`.
  static const foreground = Color(0xFFF7F9F7);

  /// `--muted-foreground: oklch(0.68 0.012 145)`. Testo secondario.
  ///
  /// Nel codice più vecchio al suo posto comparivano `Colors.white54` e
  /// `white60` sparsi: usare il token rende il grigio uniforme ovunque.
  static const muted = Color(0xFF9BA39C);

  /// Grigio ancora più tenue, per metadati marginali come i timestamp.
  static const mutedSoft = Color(0xFF6E756F);

  /// `--destructive`.
  static const danger = Color(0xFFFF6B72);

  /// Oro della fascia da capitano e dei trofei.
  static const gold = Color(0xFFFFD84D);

  // --- Raggi (`--radius: 0.8rem` = 12.8px, con le scale del tema) ---

  /// `rounded-lg`: pulsanti e campi.
  static const radiusMd = 13.0;

  /// `rounded-xl`: card.
  static const radiusLg = 18.0;

  /// Fogli modali e contenitori grandi.
  static const radiusXl = 26.0;

  /// Font dell'interfaccia: lo stesso Geist della PWA.
  ///
  /// I file stanno in `assets/fonts/` perché Geist è distribuito da Vercel e
  /// non è nel catalogo Google Fonts. Essendo impacchettati nell'app, il font
  /// è disponibile dal primo frame: nessuna dipendenza dalla rete e nessuno
  /// sfarfallio con il font di sistema all'avvio.
  static const fontFamily = 'Geist';

  static TextTheme _fontOf(TextTheme base) =>
      base.apply(fontFamily: fontFamily);

  static ThemeData get dark {
    const colors = ColorScheme.dark(
      primary: primary,
      onPrimary: onPrimary,
      secondary: Color(0xFFB8F5B2),
      onSecondary: onPrimary,
      // Material userebbe un verde chiaro di default per i controlli "tonali"
      // (IconButton.filledTonal della campanella notifiche, del + partite e
      // del + leghe), che stonava con il resto dell'interfaccia scura. Qui li
      // riportiamo sulla superficie rialzata del design system.
      secondaryContainer: surfaceHigh,
      onSecondaryContainer: foreground,
      surface: surface,
      onSurface: foreground,
      error: danger,
      onError: Color(0xFF240004),
      outline: outlineSolid,
      outlineVariant: outline,
      surfaceContainerLowest: background,
      surfaceContainerLow: Color(0xFF101311),
      surfaceContainer: surface,
      surfaceContainerHigh: surfaceHigh,
      surfaceContainerHighest: Color(0xFF242A26),
    );

    final base = ThemeData(
      brightness: Brightness.dark,
      // Anche a livello di tema, non solo di textTheme: così lo prendono pure
      // i widget che costruiscono uno stile da zero (tooltip, date picker,
      // menu di sistema) invece di ricadere sul font di sistema.
      fontFamily: fontFamily,
      colorScheme: colors,
      // Trasparente di proposito: lo sfondo (nero pieno più alone verde) lo
      // dipinge `KicklyBackdrop` una volta sola dietro a tutto, altrimenti ogni
      // Scaffold lo coprirebbe con il suo nero piatto.
      scaffoldBackgroundColor: Colors.transparent,
      useMaterial3: true,
      visualDensity: VisualDensity.standard,
      splashFactory: InkSparkle.splashFactory,
    );

    final text = _fontOf(
      base.textTheme.apply(bodyColor: foreground, displayColor: foreground),
    );

    return base.copyWith(
      textTheme: text.copyWith(
        // Titoli molto pesanti e con crenatura negativa, come le classi
        // `font-black tracking-tight` della PWA.
        headlineLarge: text.headlineLarge?.copyWith(
          fontSize: 36,
          fontWeight: FontWeight.w900,
          letterSpacing: -1.2,
          height: 1.05,
        ),
        headlineMedium: text.headlineMedium?.copyWith(
          fontSize: 27,
          fontWeight: FontWeight.w800,
          letterSpacing: -.8,
          height: 1.1,
        ),
        titleLarge: text.titleLarge?.copyWith(
          fontSize: 20,
          fontWeight: FontWeight.w800,
          letterSpacing: -.4,
        ),
        titleMedium: text.titleMedium?.copyWith(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          letterSpacing: -.2,
        ),
        bodyLarge: text.bodyLarge?.copyWith(fontSize: 15, height: 1.45),
        bodyMedium: text.bodyMedium?.copyWith(fontSize: 14, height: 1.5),
        bodySmall: text.bodySmall?.copyWith(color: muted, fontSize: 12.5),
        labelLarge: text.labelLarge?.copyWith(
          fontSize: 14,
          fontWeight: FontWeight.w800,
        ),
        labelSmall: text.labelSmall?.copyWith(color: muted, fontSize: 11),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: text.titleLarge?.copyWith(
          fontSize: 19,
          fontWeight: FontWeight.w800,
          letterSpacing: -.3,
        ),
      ),
      cardTheme: CardThemeData(
        color: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLg),
          side: const BorderSide(color: outline),
        ),
      ),
      dividerTheme: const DividerThemeData(color: outline, thickness: 1),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceHigh,
        hintStyle: const TextStyle(color: muted),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 15,
        ),
        border: _inputBorder(outline),
        enabledBorder: _inputBorder(outline),
        focusedBorder: _inputBorder(primary, width: 1.5),
        errorBorder: _inputBorder(danger),
        focusedErrorBorder: _inputBorder(danger, width: 1.5),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 48),
          foregroundColor: foreground,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
          ),
          side: const BorderSide(color: outlineSolid),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: surfaceHigh,
        // `rounded-4xl` sul web: di fatto una pillola.
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        side: const BorderSide(color: outline),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        labelStyle: const TextStyle(
          color: Color(0xFFD7DDD7),
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: primary,
        linearTrackColor: surfaceHigh,
        circularTrackColor: Colors.transparent,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(radiusXl)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLg),
          side: const BorderSide(color: outline),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: surfaceHigh,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          side: const BorderSide(color: outline),
        ),
      ),
      navigationBarTheme: const NavigationBarThemeData(
        backgroundColor: Color(0xFA0B0D0C),
        indicatorColor: Colors.transparent,
        height: 66,
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: primary,
        unselectedLabelColor: muted,
        indicatorColor: primary,
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: outline,
        labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
        unselectedLabelStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: surfaceHigh,
        contentTextStyle: const TextStyle(color: foreground, fontSize: 13.5),
        actionTextColor: primary,
        behavior: SnackBarBehavior.floating,
        insetPadding: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          side: const BorderSide(color: outline),
        ),
      ),
      // Transizione più morbida di quella predefinita di Material su Android,
      // che entra dal basso: qui le pagine scorrono di lato come nella PWA.
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }

  static OutlineInputBorder _inputBorder(Color color, {double width = 1}) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusMd),
        borderSide: BorderSide(color: color, width: width),
      );
}

/// Alone verde in alto, dietro a tutta l'app.
///
/// Riproduce il `radial-gradient(circle at 50% -20%, primary 5%, transparent
/// 35%)` che la PWA applica al body. Senza, lo sfondo mobile è nero piatto ed è
/// una delle ragioni per cui l'app sembrava più spenta del web.
class KicklyBackdrop extends StatelessWidget {
  const KicklyBackdrop({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppTheme.background,
        gradient: RadialGradient(
          // 50% orizzontale, -20% verticale come sul web.
          center: Alignment(0, -1.2),
          radius: .9,
          colors: [Color(0x14C7FF3D), Color(0x00C7FF3D)],
          stops: [0, .62],
        ),
      ),
      child: child,
    );
  }
}
