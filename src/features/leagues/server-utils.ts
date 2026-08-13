import "server-only";

import { randomBytes } from "node:crypto";

const allowedLogoTypes = new Set(["image/jpeg", "image/png", "image/webp"]);
export const maxLogoBytes = 5 * 1024 * 1024;

export function makeLeagueSlug(name: string) {
  const base = name
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "")
    .slice(0, 55) || "lega";
  return `${base}-${randomBytes(3).toString("hex")}`;
}

export function validateLogo(file: FormDataEntryValue | null): file is File {
  return (
    file instanceof File &&
    file.size > 0 &&
    file.size <= maxLogoBytes &&
    allowedLogoTypes.has(file.type)
  );
}

export function hasInvalidLogo(file: FormDataEntryValue | null) {
  return file instanceof File && file.size > 0 && !validateLogo(file);
}

export function logoExtension(file: File) {
  return file.type.split("/")[1].replace("jpeg", "jpg");
}

export function storagePathFromPublicUrl(url: string | null) {
  if (!url) return null;
  const marker = "/storage/v1/object/public/league-logos/";
  const index = url.indexOf(marker);
  return index >= 0 ? decodeURIComponent(url.slice(index + marker.length)) : null;
}
