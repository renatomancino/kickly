import Link from "next/link";
import { Bell } from "lucide-react";

export function NotificationBell({ unread }: { unread: number }) {
  return <Link aria-label={`${unread} notifiche non lette`} className="relative grid size-10 place-items-center rounded-xl border bg-card text-muted-foreground transition-colors hover:text-foreground" href="/notifications"><Bell className="size-5" />{unread > 0 ? <span className="absolute end-1 top-1 grid min-w-4 place-items-center rounded-full bg-primary px-1 text-[9px] font-black leading-4 text-primary-foreground">{Math.min(unread, 99)}</span> : null}</Link>;
}
