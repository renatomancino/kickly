import type { MetadataRoute } from "next";

export default function manifest(): MetadataRoute.Manifest {
  return {
    name: "Kickly - Il calcio, organizzato",
    short_name: "Kickly",
    description: "Leghe, partite e statistiche del tuo gruppo di calcio.",
    start_url: "/dashboard",
    display: "standalone",
    background_color: "#111512",
    theme_color: "#c7ff3d",
    orientation: "portrait-primary",
    icons: [
      { src: "/icons/kickly-icon-192.svg", sizes: "192x192", type: "image/svg+xml", purpose: "any" },
      { src: "/icons/kickly-icon-512.svg", sizes: "512x512", type: "image/svg+xml", purpose: "maskable" },
    ],
  };
}
