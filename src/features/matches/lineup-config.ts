import type { MatchFormat } from "@/types/database";

export type LineupRole = "goalkeeper" | "defender" | "midfielder" | "forward";

export interface LineupSlotDefinition {
  key: string;
  x: number;
  y: number;
  role: LineupRole;
  roleLabel: string;
}

export const formationOptions: Record<MatchFormat, readonly string[]> = {
  "5v5": ["1-2-1", "2-1-1", "1-1-2"],
  "7v7": ["2-3-1", "3-2-1", "2-2-2"],
  "8v8": ["3-3-1", "2-3-2", "3-2-2"],
  "10v10": ["3-4-2", "4-3-2", "4-4-1"],
  "11v11": ["4-3-3", "4-4-2", "3-5-2"],
};

export const defaultFormation: Record<MatchFormat, string> = {
  "5v5": "1-2-1",
  "7v7": "2-3-1",
  "8v8": "3-3-1",
  "10v10": "3-4-2",
  "11v11": "4-3-3",
};

export function sideSize(format: MatchFormat) {
  return Number(format.split("v")[0]);
}

export function buildLineupSlots(format: MatchFormat, formation: string): LineupSlotDefinition[] {
  const chosenFormation = formationOptions[format].includes(formation)
    ? formation
    : defaultFormation[format];
  const lines = chosenFormation.split("-").map(Number);
  const lineY = [72, 50, 27];
  const roles: LineupRole[] = ["defender", "midfielder", "forward"];
  const roleLabels = ["D", "C", "A"];
  let outfieldIndex = 1;

  const slots: LineupSlotDefinition[] = [{
    key: "gk",
    x: 50,
    y: 91,
    role: "goalkeeper",
    roleLabel: "P",
  }];

  lines.forEach((count, lineIndex) => {
    for (let position = 0; position < count; position += 1) {
      slots.push({
        key: `p${outfieldIndex}`,
        x: ((position + 1) * 100) / (count + 1),
        y: lineY[lineIndex] ?? 50,
        role: roles[lineIndex] ?? "midfielder",
        roleLabel: roleLabels[lineIndex] ?? "C",
      });
      outfieldIndex += 1;
    }
  });

  return slots.slice(0, sideSize(format));
}
