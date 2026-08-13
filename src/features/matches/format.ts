import type { MatchStatus } from "@/types/database";

export function matchDateLabel(value: string) {
  return new Intl.DateTimeFormat("it-IT", {
    weekday: "long",
    day: "numeric",
    month: "long",
  }).format(new Date(value));
}

export function matchTimeLabel(value: string) {
  return new Intl.DateTimeFormat("it-IT", {
    hour: "2-digit",
    minute: "2-digit",
  }).format(new Date(value));
}

export function matchShortDate(value: string) {
  return new Intl.DateTimeFormat("it-IT", {
    day: "2-digit",
    month: "short",
  }).format(new Date(value));
}

export function matchStatusLabel(status: MatchStatus, closedAt: string | null) {
  if (status === "cancelled") return "Annullata";
  if (status === "completed") return "Conclusa";
  if (closedAt) return "Iscrizioni chiuse";
  if (status === "full") return "Completa";
  if (status === "draft") return "Bozza";
  return "Aperta";
}

export function mapsUrl(locationName: string, address: string | null, city: string) {
  const query = [locationName, address, city].filter(Boolean).join(", ");
  return `https://www.google.com/maps/search/?api=1&query=${encodeURIComponent(query)}`;
}
