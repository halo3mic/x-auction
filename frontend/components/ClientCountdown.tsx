"use client";

import { Clock } from "lucide-react";
import Countdown from "react-countdown";

interface ClientCountdownProps {
  endTime: number;
}

export function ClientCountdown({ endTime }: ClientCountdownProps) {
  return (
    <p className="text-sm font-semibold flex items-center justify-end bg-primary/10 rounded-full px-3 py-1">
      <Clock className="mr-1 text-primary" size={14} />
      <Countdown
        date={endTime}
        renderer={({ days, hours, minutes }) => (
          <span className="text-primary font-bold">
            {days}d {hours}h {minutes}m
          </span>
        )}
      />
    </p>
  );
}
