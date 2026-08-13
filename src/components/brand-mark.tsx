import { cn } from "@/lib/utils";

export function BrandMark({ className }: { className?: string }) {
  return (
    <span
      aria-hidden="true"
      className={cn(
        "grid size-9 place-items-center rounded-xl bg-primary text-base font-black text-primary-foreground shadow-[0_0_28px_-7px_var(--primary)]",
        className,
      )}
    >
      K
    </span>
  );
}
