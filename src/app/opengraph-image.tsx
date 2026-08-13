import { ImageResponse } from "next/og";

export const alt = "Kickly - Your game. Your story.";
export const size = { width: 1200, height: 630 };
export const contentType = "image/png";

export default function OpenGraphImage() {
  return new ImageResponse(
    <div style={{ width: "100%", height: "100%", display: "flex", alignItems: "center", justifyContent: "space-between", padding: "72px 82px", color: "#f8fff8", background: "radial-gradient(circle at 78% 10%, #31451f 0%, #151b16 42%, #0d110e 100%)", fontFamily: "sans-serif" }}>
      <div style={{ display: "flex", flexDirection: "column", width: 700 }}>
        <div style={{ display: "flex", alignItems: "center", gap: 20, fontSize: 34, fontWeight: 800 }}><span style={{ display: "flex", width: 62, height: 62, borderRadius: 18, alignItems: "center", justifyContent: "center", color: "#151b16", background: "#c7ff3d", fontSize: 38, fontWeight: 900 }}>K</span>Kickly</div>
        <div style={{ display: "flex", flexDirection: "column", marginTop: 64, fontSize: 72, lineHeight: 0.98, fontWeight: 900, letterSpacing: -3 }}>Organizza la partita.<span style={{ color: "#c7ff3d" }}>Scrivi la tua storia.</span></div>
        <div style={{ marginTop: 34, color: "#aeb8af", fontSize: 27 }}>Leghe, convocazioni e statistiche in un’unica app.</div>
      </div>
      <div style={{ display: "flex", flexDirection: "column", width: 290, padding: 28, border: "2px solid #425043", borderRadius: 34, background: "#1a211b" }}>
        <div style={{ color: "#aeb8af", fontSize: 18 }}>PROSSIMA PARTITA</div><div style={{ marginTop: 10, fontSize: 28, fontWeight: 800 }}>Giovedì sotto le luci</div><div style={{ display: "flex", marginTop: 30, padding: 18, borderRadius: 20, background: "#111612", fontSize: 22 }}>⚽ 5 vs 5 · 21:00</div><div style={{ display: "flex", marginTop: 16, color: "#c7ff3d", fontSize: 20, fontWeight: 800 }}>8 / 10 giocatori</div>
      </div>
    </div>,
    size,
  );
}
